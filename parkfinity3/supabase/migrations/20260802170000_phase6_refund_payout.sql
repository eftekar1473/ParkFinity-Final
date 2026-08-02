-- Phase 6 — Refund on cancel + owner payout on completion.
-- Money is server-authoritative: refund policy + commission split live in SQL.

-- ---------- 1. cancel_booking: now refunds per policy ----------
-- Policy (platform_settings): >= refund_full_hours before start = full refund;
-- before start but inside window = refund_partial_pct; after start = no refund.
CREATE OR REPLACE FUNCTION cancel_booking(p_booking UUID, p_actor UUID)
RETURNS TABLE (ok BOOLEAN, msg TEXT) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  b_status   TEXT;
  b_rider    UUID;
  b_listing  UUID;
  b_vtype    TEXT;
  b_qty      INT;
  b_start    TIMESTAMPTZ;
  b_total    NUMERIC;
  full_hours INT;
  part_pct   NUMERIC;
  refund     NUMERIC := 0;
  hrs_to_go  NUMERIC;
BEGIN
  SELECT status::text, rider_id, listing_id, vehicle_type, slot_qty, start_time, total_amount
    INTO b_status, b_rider, b_listing, b_vtype, b_qty, b_start, b_total
  FROM bookings WHERE id = p_booking FOR UPDATE;

  IF NOT FOUND THEN RETURN QUERY SELECT FALSE, 'Booking not found'; RETURN; END IF;
  IF b_rider <> p_actor THEN RETURN QUERY SELECT FALSE, 'Not your booking'; RETURN; END IF;
  IF b_status IN ('Cancelled','Completed','Refunded','Overstayed') THEN
    RETURN QUERY SELECT FALSE, 'Booking already ' || b_status; RETURN;
  END IF;

  SELECT refund_full_hours, refund_partial_pct INTO full_hours, part_pct
  FROM platform_settings LIMIT 1;
  full_hours := COALESCE(full_hours, 24);
  part_pct   := COALESCE(part_pct, 0.50);

  hrs_to_go := EXTRACT(EPOCH FROM (b_start - now())) / 3600.0;
  IF hrs_to_go >= full_hours THEN
    refund := b_total;                    -- full
  ELSIF hrs_to_go > 0 THEN
    refund := round(b_total * part_pct, 2); -- partial
  ELSE
    refund := 0;                          -- started already, no refund
  END IF;

  -- Release slot + set status. Refunded status only if money returned.
  IF b_vtype IS NOT NULL THEN
    PERFORM release_slot(b_listing, b_vtype, COALESCE(b_qty, 1));
  END IF;

  IF refund > 0 THEN
    UPDATE profiles SET wallet_balance = wallet_balance + refund WHERE id = b_rider;
    INSERT INTO transactions (user_id, amount, type, status, reference_id)
    VALUES (b_rider, refund, 'refund', 'Completed', p_booking::varchar);
    UPDATE bookings SET status = 'Refunded', is_refunded = TRUE, updated_at = now()
    WHERE id = p_booking;
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (b_rider, 'Booking refunded',
            'Cancelled — ৳' || round(refund) || ' returned to your wallet.',
            'payment', jsonb_build_object('booking_id', p_booking, 'refund', refund));
    RETURN QUERY SELECT TRUE, 'Refunded ' || round(refund)::text;
  ELSE
    UPDATE bookings SET status = 'Cancelled', updated_at = now() WHERE id = p_booking;
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (b_rider, 'Booking cancelled',
            'Cancelled. No refund (session already started or past policy window).',
            'payment', jsonb_build_object('booking_id', p_booking));
    RETURN QUERY SELECT TRUE, 'Cancelled (no refund)';
  END IF;
END; $$;

-- ---------- 2. complete_booking: credit owner earnings ----------
-- On completion the platform releases the owner's cut (total - commission) to
-- their wallet and records an earning transaction. Idempotent per booking.
CREATE OR REPLACE FUNCTION complete_booking(p_booking UUID)
RETURNS TABLE (ok BOOLEAN, msg TEXT) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  b_status   TEXT;
  b_listing  UUID;
  b_earn     NUMERIC;
  v_owner    UUID;
BEGIN
  SELECT status::text, listing_id, owner_earnings
    INTO b_status, b_listing, b_earn
  FROM bookings WHERE id = p_booking FOR UPDATE;

  IF NOT FOUND THEN RETURN QUERY SELECT FALSE, 'Booking not found'; RETURN; END IF;
  IF b_status = 'Completed' THEN RETURN QUERY SELECT FALSE, 'Already completed'; RETURN; END IF;
  IF b_status NOT IN ('Confirmed','Active') THEN
    RETURN QUERY SELECT FALSE, 'Cannot complete a ' || b_status; RETURN;
  END IF;

  SELECT owner_id INTO v_owner FROM listings WHERE id = b_listing;

  UPDATE bookings SET status = 'Completed', actual_end_time = now(), updated_at = now()
  WHERE id = p_booking;

  IF v_owner IS NOT NULL AND COALESCE(b_earn,0) > 0 THEN
    UPDATE profiles SET wallet_balance = wallet_balance + b_earn WHERE id = v_owner;
    INSERT INTO transactions (user_id, amount, type, status, reference_id)
    VALUES (v_owner, b_earn, 'earning', 'Completed', p_booking::varchar);
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (v_owner, 'Earnings credited',
            '৳' || round(b_earn) || ' added to your wallet from a completed booking.',
            'payment', jsonb_build_object('booking_id', p_booking, 'amount', b_earn));
  END IF;

  RETURN QUERY SELECT TRUE, 'Completed';
END; $$;

GRANT EXECUTE ON FUNCTION cancel_booking(UUID, UUID)   TO authenticated;
GRANT EXECUTE ON FUNCTION complete_booking(UUID)        TO authenticated, service_role;
