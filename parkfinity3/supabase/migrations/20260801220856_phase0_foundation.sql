-- ============================================================
-- Phase 0 - Backend Foundation (idempotent, additive, safe re-run)
-- ParkFinityDB. Keeps legacy columns (available_slots/total_slots)
-- working so the current client keeps functioning during transition.
-- NOTE: enum ADD VALUE lives in a separate earlier-timestamp migration
-- so new values are committed before any function references them.
-- ============================================================

-- ---------- 1. profiles: KYC documents + FCM token ----------
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS kyc_status    TEXT NOT NULL DEFAULT 'none', -- none|pending|verified
  ADD COLUMN IF NOT EXISTS nid_front_url TEXT,
  ADD COLUMN IF NOT EXISTS nid_back_url  TEXT,
  ADD COLUMN IF NOT EXISTS license_url   TEXT,
  ADD COLUMN IF NOT EXISTS property_docs JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS fcm_token     TEXT;

-- Existing users predate KYC gating: grandfather them in so they are not locked out.
UPDATE profiles SET kyc_status = 'verified' WHERE kyc_status = 'none';

-- ---------- 2. listings: per-type slots + schedule + mode + yearly ----------
ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS yearly_rate           DECIMAL(10,2),
  ADD COLUMN IF NOT EXISTS slot_capacity         JSONB NOT NULL DEFAULT '{}'::jsonb, -- {"Car":10,"Motorcycle":5}
  ADD COLUMN IF NOT EXISTS slot_available        JSONB NOT NULL DEFAULT '{}'::jsonb, -- decremented live
  ADD COLUMN IF NOT EXISTS availability_schedule JSONB,                              -- weekly open/close
  ADD COLUMN IF NOT EXISTS booking_mode          TEXT NOT NULL DEFAULT 'instant';    -- instant|manual

-- Backfill slot maps from legacy total_slots/available_slots for existing rows.
DO $$
DECLARE r RECORD; cap jsonb; avail jsonb; vt text;
BEGIN
  FOR r IN
    SELECT id, allowed_vehicle_types, total_slots, available_slots
    FROM listings
    WHERE slot_capacity = '{}'::jsonb
      AND allowed_vehicle_types IS NOT NULL
      AND array_length(allowed_vehicle_types, 1) > 0
  LOOP
    cap := '{}'::jsonb; avail := '{}'::jsonb;
    FOREACH vt IN ARRAY r.allowed_vehicle_types::text[]
    LOOP
      cap   := jsonb_set(cap,   ARRAY[vt], to_jsonb(GREATEST(COALESCE(r.total_slots,0), 0)));
      avail := jsonb_set(avail, ARRAY[vt], to_jsonb(GREATEST(COALESCE(r.available_slots,0), 0)));
    END LOOP;
    UPDATE listings SET slot_capacity = cap, slot_available = avail WHERE id = r.id;
  END LOOP;
END $$;

-- ---------- 3. bookings: duration/type/amounts/refund ----------
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS duration_type   TEXT,                          -- Hourly|Daily|Weekly|Monthly|Yearly
  ADD COLUMN IF NOT EXISTS vehicle_type    TEXT,                          -- snapshot of booked vehicle type
  ADD COLUMN IF NOT EXISTS slot_qty        INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS base_amount     DECIMAL(10,2),
  ADD COLUMN IF NOT EXISTS overstay_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_refunded     BOOLEAN NOT NULL DEFAULT FALSE;

-- ---------- 4. notifications: complete the schema ----------
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'system', -- booking|payment|overstay|reminder|system
  ADD COLUMN IF NOT EXISTS data JSONB;

-- ---------- 5. platform_settings: single-row config ----------
CREATE TABLE IF NOT EXISTS platform_settings (
  id                  BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id),  -- enforces single row
  commission_rate     DECIMAL(4,3) NOT NULL DEFAULT 0.100,          -- 10%
  peak_multiplier     DECIMAL(4,2) NOT NULL DEFAULT 1.50,
  weekend_multiplier  DECIMAL(4,2) NOT NULL DEFAULT 1.20,
  overstay_multiplier DECIMAL(4,2) NOT NULL DEFAULT 2.00,
  refund_full_hours   INTEGER NOT NULL DEFAULT 24,                  -- >=24h before start = full refund
  refund_partial_pct  DECIMAL(4,2) NOT NULL DEFAULT 0.50,           -- <24h before start = 50%
  updated_at          TIMESTAMPTZ DEFAULT now()
);
INSERT INTO platform_settings (id) VALUES (TRUE) ON CONFLICT (id) DO NOTHING;

ALTER TABLE platform_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ps_read ON platform_settings;
CREATE POLICY ps_read ON platform_settings FOR SELECT USING (true); -- world-readable (rates shown in UI)
-- writes only via service role / admin RPC (no INSERT/UPDATE policy = blocked for anon/authenticated)

-- ---------- 6. Atomic slot RPCs (race-safe, replace decrement_slots) ----------
CREATE OR REPLACE FUNCTION book_slot(p_listing UUID, p_vtype TEXT, p_qty INT DEFAULT 1)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE avail INT;
BEGIN
  SELECT COALESCE((slot_available->>p_vtype)::int, 0) INTO avail
  FROM listings WHERE id = p_listing FOR UPDATE;
  IF avail < p_qty THEN RETURN FALSE; END IF;
  UPDATE listings
    SET slot_available = jsonb_set(slot_available, ARRAY[p_vtype], to_jsonb(avail - p_qty)),
        available_slots = GREATEST(COALESCE(available_slots,0) - p_qty, 0) -- keep legacy col in sync
  WHERE id = p_listing;
  RETURN TRUE;
END; $$;

CREATE OR REPLACE FUNCTION release_slot(p_listing UUID, p_vtype TEXT, p_qty INT DEFAULT 1)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE avail INT; cap INT;
BEGIN
  SELECT COALESCE((slot_available->>p_vtype)::int, 0),
         COALESCE((slot_capacity ->>p_vtype)::int, 0)
    INTO avail, cap
  FROM listings WHERE id = p_listing FOR UPDATE;
  UPDATE listings
    SET slot_available = jsonb_set(slot_available, ARRAY[p_vtype], to_jsonb(LEAST(avail + p_qty, GREATEST(cap, avail + p_qty)))),
        available_slots = COALESCE(available_slots,0) + p_qty
  WHERE id = p_listing;
END; $$;

-- Legacy shim: keep decrement_slots working but route it through the new logic is not
-- possible without a vtype; leave the old function intact if present. New code uses book_slot.

-- ---------- 7. Helper: current platform commission rate ----------
CREATE OR REPLACE FUNCTION current_commission_rate()
RETURNS DECIMAL LANGUAGE sql STABLE AS $$
  SELECT commission_rate FROM platform_settings WHERE id = TRUE;
$$;

-- ---------- 8. Indexes for hot query paths ----------
CREATE INDEX IF NOT EXISTS idx_bookings_status_end   ON bookings(status, end_time);
CREATE INDEX IF NOT EXISTS idx_bookings_rider        ON bookings(rider_id);
CREATE INDEX IF NOT EXISTS idx_bookings_listing      ON bookings(listing_id);
CREATE INDEX IF NOT EXISTS idx_listings_owner        ON listings(owner_id);
CREATE INDEX IF NOT EXISTS idx_listings_active       ON listings(is_active);
CREATE INDEX IF NOT EXISTS idx_notifications_user    ON notifications(user_id, is_read);
