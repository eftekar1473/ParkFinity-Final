-- ============================================================
-- Phase 4 — Booking engine backend
--  * harden book_slot (NULL-listing bug: returned TRUE for missing listing)
--  * demand helper for demand-driven peak pricing
--  * atomic cancel_booking (status + slot release in one txn)
-- ============================================================

-- ---------- 1. Harden book_slot ----------
-- Old bug: SELECT ... INTO avail found no row for a bad/inactive listing, leaving
-- avail NULL; `NULL < p_qty` is NULL (not TRUE) so the guard fell through and the
-- UPDATE no-op'd yet still RETURN TRUE. Now we detect the missing row explicitly.
CREATE OR REPLACE FUNCTION book_slot(p_listing UUID, p_vtype TEXT, p_qty INT DEFAULT 1)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  avail   INT;
  is_live BOOLEAN;
BEGIN
  SELECT COALESCE((slot_available->>p_vtype)::int, 0), is_active
    INTO avail, is_live
  FROM listings WHERE id = p_listing FOR UPDATE;

  IF NOT FOUND THEN RETURN FALSE; END IF;   -- no such listing
  IF is_live IS NOT TRUE THEN RETURN FALSE; END IF;
  IF avail < p_qty THEN RETURN FALSE; END IF;

  UPDATE listings
    SET slot_available = jsonb_set(slot_available, ARRAY[p_vtype], to_jsonb(avail - p_qty)),
        available_slots = GREATEST(COALESCE(available_slots,0) - p_qty, 0)
  WHERE id = p_listing;
  RETURN TRUE;
END; $$;

-- ---------- 2. Demand helper: rolling 7-day density for an hour bucket ----------
-- Returns bookings for this listing that started in the same hour-of-day over the
-- last 7 days. create-booking maps this to a bounded peak multiplier.
CREATE OR REPLACE FUNCTION listing_hour_demand(p_listing UUID, p_hour INT)
RETURNS INT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COUNT(*)::int
  FROM bookings
  WHERE listing_id = p_listing
    AND status <> 'Cancelled'
    AND created_at >= now() - interval '7 days'
    AND EXTRACT(HOUR FROM start_time) = p_hour;
$$;

-- ---------- 3. Atomic cancel: set status + release slot together ----------
CREATE OR REPLACE FUNCTION cancel_booking(p_booking UUID, p_actor UUID)
RETURNS TABLE (ok BOOLEAN, msg TEXT) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  b_status  TEXT;
  b_rider   UUID;
  b_listing UUID;
  b_vtype   TEXT;
  b_qty     INT;
BEGIN
  SELECT status::text, rider_id, listing_id, vehicle_type, slot_qty
    INTO b_status, b_rider, b_listing, b_vtype, b_qty
  FROM bookings WHERE id = p_booking FOR UPDATE;

  IF NOT FOUND THEN RETURN QUERY SELECT FALSE, 'Booking not found'; RETURN; END IF;
  IF b_rider <> p_actor THEN RETURN QUERY SELECT FALSE, 'Not your booking'; RETURN; END IF;
  IF b_status IN ('Cancelled','Completed','Refunded','Overstayed') THEN
    RETURN QUERY SELECT FALSE, 'Booking already ' || b_status; RETURN;
  END IF;

  UPDATE bookings SET status = 'Cancelled', updated_at = now() WHERE id = p_booking;

  IF b_vtype IS NOT NULL THEN
    PERFORM release_slot(b_listing, b_vtype, COALESCE(b_qty, 1));
  END IF;

  RETURN QUERY SELECT TRUE, 'Cancelled';
END; $$;

-- ---------- 4. Extend guard: next booking of same slot ----------
-- Earliest start of another live booking on this listing that begins after p_from.
-- create-booking / extend uses this to cap how far an extension can push end_time.
CREATE OR REPLACE FUNCTION next_booking_start(p_listing UUID, p_exclude UUID, p_from TIMESTAMPTZ)
RETURNS TIMESTAMPTZ LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT MIN(start_time)
  FROM bookings
  WHERE listing_id = p_listing
    AND id <> p_exclude
    AND status IN ('Pending','Confirmed','Active')
    AND start_time >= p_from;
$$;

GRANT EXECUTE ON FUNCTION cancel_booking(UUID, UUID)              TO authenticated;
GRANT EXECUTE ON FUNCTION listing_hour_demand(UUID, INT)         TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION next_booking_start(UUID, UUID, TIMESTAMPTZ) TO authenticated, service_role;
