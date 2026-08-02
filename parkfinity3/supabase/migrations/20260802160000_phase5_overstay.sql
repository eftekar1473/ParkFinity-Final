-- Phase 5 — Overstay detection, charge, notify, slot release. Single engine + pg_cron.
-- Replaces the two divergent edge functions (detect-overstay / overstay-checker).

-- 1. payment_due flag: set when overstay penalty cannot be collected (wallet short).
--    Blocks new bookings until settled.
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS payment_due BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS has_payment_due BOOLEAN NOT NULL DEFAULT FALSE;

-- Penalty multiplier lives in platform_settings so admin can tune it (Phase 9).
ALTER TABLE platform_settings
  ADD COLUMN IF NOT EXISTS overstay_penalty_multiplier NUMERIC NOT NULL DEFAULT 2.0;

-- ===========================================================================
-- process_overstays(): the single overstay engine. Idempotent, race-safe.
-- Called directly by pg_cron (no HTTP hop, no service key) and exposed as RPC
-- so the thin overstay-checker edge fn / admin can trigger manually.
-- ===========================================================================
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
  v_balance    NUMERIC;
  v_processed  INT := 0;
  v_charged    INT := 0;
  v_flagged    INT := 0;
BEGIN
  SELECT COALESCE(overstay_penalty_multiplier, 2.0) INTO v_mult
  FROM platform_settings LIMIT 1;
  IF v_mult IS NULL THEN v_mult := 2.0; END IF;

  -- Candidates: running booking whose end_time has passed and no checkout yet.
  -- Confirmed OR Active (both are "in progress"). Lock rows so concurrent cron
  -- ticks never double-charge.
  FOR b IN
    SELECT bk.id, bk.rider_id, bk.listing_id, bk.vehicle_type, bk.end_time,
           l.owner_id, l.hourly_rate
    FROM bookings bk
    JOIN listings l ON l.id = bk.listing_id
    WHERE bk.status IN ('Confirmed', 'Active')
      AND bk.end_time < now()
      AND bk.actual_end_time IS NULL
    FOR UPDATE OF bk SKIP LOCKED
  LOOP
    v_processed := v_processed + 1;

    v_hours := GREATEST(1, CEIL(EXTRACT(EPOCH FROM (now() - b.end_time)) / 3600.0)::INT);
    v_rate  := COALESCE(b.hourly_rate, 10);
    v_penalty := v_hours * v_rate * v_mult;

    SELECT wallet_balance INTO v_balance FROM profiles WHERE id = b.rider_id FOR UPDATE;
    v_balance := COALESCE(v_balance, 0);

    IF v_balance >= v_penalty THEN
      -- Collect penalty from wallet.
      UPDATE profiles SET wallet_balance = wallet_balance - v_penalty WHERE id = b.rider_id;
      INSERT INTO transactions (user_id, amount, type, status, reference_id)
      VALUES (b.rider_id, v_penalty, 'overstay_charge', 'Completed', b.id::varchar);

      UPDATE bookings
      SET status = 'Overstayed', overstay_amount = v_penalty, payment_due = FALSE
      WHERE id = b.id;
      v_charged := v_charged + 1;
    ELSE
      -- Cannot collect: flag due, still mark overstayed so slot frees.
      UPDATE bookings
      SET status = 'Overstayed', overstay_amount = v_penalty, payment_due = TRUE
      WHERE id = b.id;
      UPDATE profiles SET has_payment_due = TRUE WHERE id = b.rider_id;
      v_flagged := v_flagged + 1;
    END IF;

    -- Free the slot back to inventory (per-type).
    PERFORM release_slot(b.listing_id, b.vehicle_type, 1);

    -- Notify rider + owner (in-app; push handled in Phase 8 send-push).
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (
      b.rider_id, 'Overstay charged',
      'You overstayed by ' || v_hours || 'h. Penalty ৳' || round(v_penalty) ||
        CASE WHEN v_balance >= v_penalty THEN ' charged.' ELSE ' due — settle to book again.' END,
      'overstay', jsonb_build_object('booking_id', b.id, 'penalty', v_penalty, 'hours', v_hours)
    );
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (
      b.owner_id, 'Rider overstayed',
      'A rider overstayed at your spot. Slot has been released.',
      'overstay', jsonb_build_object('booking_id', b.id)
    );
  END LOOP;

  RETURN jsonb_build_object(
    'processed', v_processed, 'charged', v_charged, 'flagged', v_flagged
  );
END;
$$;

REVOKE ALL ON FUNCTION process_overstays() FROM PUBLIC, anon, authenticated;

-- ===========================================================================
-- Schedule it: pg_cron calls the SQL engine directly every 10 minutes.
-- No HTTP hop / service key needed — fully in-database and free.
-- ===========================================================================
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Idempotent: drop any prior schedule of this name before re-creating.
DO $$
BEGIN
  PERFORM cron.unschedule('overstay-sweep')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'overstay-sweep');
END $$;

SELECT cron.schedule('overstay-sweep', '*/10 * * * *', $$SELECT process_overstays();$$);

