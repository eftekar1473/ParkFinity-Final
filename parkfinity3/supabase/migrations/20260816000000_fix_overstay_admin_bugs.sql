-- ============================================================
-- Phase 19 - Fix overstay logic, admin controls, and KYC
-- ============================================================

-- 1. Admin suspension toggle
ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. KYC driving license back
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS driving_license_back_url TEXT;

-- 3. Modify process_overstays to NOT auto-checkout, NOT release slot, and NOT charge wallet immediately.
CREATE OR REPLACE FUNCTION process_overstays()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  b            RECORD;
  v_hours      INT;
  v_rate       NUMERIC;
  v_mult       NUMERIC;
  v_penalty    NUMERIC;
  v_processed  INT := 0;
  v_flagged    INT := 0;
BEGIN
  SELECT COALESCE(overstay_penalty_multiplier, 2.0) INTO v_mult
  FROM platform_settings LIMIT 1;
  IF v_mult IS NULL THEN v_mult := 2.0; END IF;

  FOR b IN
    SELECT bk.id, bk.rider_id, bk.listing_id, bk.vehicle_type, bk.end_time,
           l.owner_id, l.hourly_rate
    FROM bookings bk
    JOIN listings l ON l.id = bk.listing_id
    WHERE bk.status IN ('Confirmed', 'Active', 'Overstayed')
      AND bk.end_time < now()
      AND bk.actual_end_time IS NULL
    FOR UPDATE OF bk SKIP LOCKED
  LOOP
    v_processed := v_processed + 1;

    v_hours := GREATEST(1, CEIL(EXTRACT(EPOCH FROM (now() - b.end_time)) / 3600.0)::INT);
    v_rate  := COALESCE(b.hourly_rate, 10);
    v_penalty := v_hours * v_rate * v_mult;

    -- Update penalty but DO NOT charge yet. Wait for check_out.
    UPDATE bookings
    SET status = 'Overstayed', overstay_amount = v_penalty
    WHERE id = b.id;
    v_flagged := v_flagged + 1;

  END LOOP;

  RETURN jsonb_build_object(
    'processed', v_processed, 'flagged', v_flagged
  );
END;
$$;

-- 4. Modify settle_stale_bookings to remove the auto-checkout for active bookings.
CREATE OR REPLACE FUNCTION settle_stale_bookings()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r         RECORD;
  v_noshow  INT := 0;
  v_ns_min  INT;
BEGIN
  SELECT COALESCE(no_show_minutes, 30) INTO v_ns_min FROM platform_settings LIMIT 1;

  -- No-show: never checked in, window fully elapsed.
  FOR r IN
    SELECT id, rider_id FROM bookings
    WHERE status IN ('Pending','Confirmed')
      AND checked_in_at IS NULL
      AND end_time < now()
      AND no_show = FALSE
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE bookings SET no_show = TRUE WHERE id = r.id;
    PERFORM complete_booking(r.id);
    v_noshow := v_noshow + 1;
  END LOOP;

  -- Removed the Active/Overstayed auto-checkout block!
  -- They will stay active until the rider scans the QR code to leave.

  RETURN jsonb_build_object('no_show', v_noshow);
END; $$;

-- 5. Modify check_out to enforce payment for overstay.
CREATE OR REPLACE FUNCTION check_out(p_token TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_listing UUID;
  b         RECORD;
  v_rate    NUMERIC;
  v_mult    NUMERIC;
  v_hours   NUMERIC;
  v_penalty NUMERIC := 0;
  v_bal     NUMERIC;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Not authenticated');
  END IF;

  SELECT id INTO v_listing FROM listings
  WHERE (p_token ~ '^[0-9a-fA-F-]{36}$' AND qr_token = p_token::uuid)
     OR qr_short_code = upper(btrim(p_token))
  LIMIT 1;

  IF v_listing IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Unknown QR code');
  END IF;

  SELECT * INTO b FROM bookings
  WHERE rider_id = auth.uid()
    AND listing_id = v_listing
    AND checked_in_at IS NOT NULL
    AND checked_out_at IS NULL
    AND status IN ('Active','Confirmed','Overstayed')
  ORDER BY start_time DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'No checked-in booking to end');
  END IF;

  -- Overstay: charge per started hour beyond end_time at a penalty multiple.
  IF now() > b.end_time THEN
    SELECT l.hourly_rate INTO v_rate FROM listings l WHERE l.id = b.listing_id;
    SELECT COALESCE(overstay_penalty_multiplier, 2.0) INTO v_mult FROM platform_settings LIMIT 1;
    v_hours := GREATEST(1, ceil(EXTRACT(EPOCH FROM (now() - b.end_time)) / 3600.0));
    v_penalty := ROUND(COALESCE(v_rate, 0) * v_hours * v_mult, 2);
  END IF;

  IF v_penalty > 0 THEN
    SELECT wallet_balance INTO v_bal FROM profiles WHERE id = b.rider_id FOR UPDATE;
    IF COALESCE(v_bal, 0) >= v_penalty THEN
      UPDATE profiles SET wallet_balance = wallet_balance - v_penalty WHERE id = b.rider_id;
      INSERT INTO transactions (user_id, amount, type, status, reference_id)
      VALUES (b.rider_id, v_penalty, 'overstay_charge', 'Completed', b.id);
      
      UPDATE bookings SET overstay_amount = v_penalty, payment_due = FALSE WHERE id = b.id;
      UPDATE profiles SET has_payment_due = FALSE WHERE id = b.rider_id;
    ELSE
      -- BLOCK CHECKOUT!
      UPDATE bookings SET payment_due = v_penalty WHERE id = b.id;
      UPDATE profiles SET has_payment_due = TRUE WHERE id = b.rider_id;
      RETURN jsonb_build_object('ok', false, 'msg', 'Insufficient balance. Recharge ৳' || v_penalty || ' to pay your overstay fee before checking out.');
    END IF;

    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (b.rider_id, 'Overstay charge',
            'You parked ' || v_hours || 'h past your booking. Charged ৳' || v_penalty,
            'overstay', jsonb_build_object('booking_id', b.id));
  END IF;

  UPDATE bookings
  SET checked_out_at = now(), actual_end_time = now(), updated_at = now()
  WHERE id = b.id;

  -- Credits owner_earnings to the owner wallet + marks Completed.
  PERFORM complete_booking(b.id);
  PERFORM refresh_listing_availability(b.listing_id);

  RETURN jsonb_build_object('ok', true, 'msg', 'Parking ended',
                            'overstay_charge', v_penalty, 'booking_id', b.id);
END; $$;
