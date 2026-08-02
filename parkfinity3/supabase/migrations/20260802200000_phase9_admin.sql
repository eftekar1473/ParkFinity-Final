-- ============================================================
-- Phase 9 - Admin panel backend.
-- Admin visibility (RLS), privileged writes (settings, suspend),
-- and read RPCs for dashboard/reports. Idempotent / additive.
-- ParkFinityDB.
-- ============================================================

-- ---------- 0. profiles: suspension flag ----------
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN NOT NULL DEFAULT FALSE;

-- ---------- 1. is_admin() helper ----------
-- SECURITY DEFINER so it can read profiles.role regardless of the caller's
-- own RLS. Used by every admin policy below and by admin-only RPCs.
CREATE OR REPLACE FUNCTION is_admin(p_uid UUID DEFAULT auth.uid())
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = p_uid AND role = 'Admin');
$$;

-- ---------- 2. Admin read access to money tables ----------
-- transactions currently: own-rows only. Add an admin-sees-all SELECT so the
-- payment/revenue screens work. (Existing own-row policy stays.)
DROP POLICY IF EXISTS tx_admin_read ON transactions;
CREATE POLICY tx_admin_read ON transactions FOR SELECT
  USING (is_admin());

-- bookings + profiles have RLS disabled today (anon can already read).
-- Leave as-is: admin panel uses anon/authenticated and already sees them.
-- If bookings RLS is ever enabled, add: is_admin() OR rider_id=auth.uid() ...

-- ---------- 3. Admin write access to platform_settings ----------
-- Was: world-readable, no write policy (blocked for everyone but service role).
-- Add an admin-only UPDATE so the settings screen can save.
DROP POLICY IF EXISTS ps_admin_update ON platform_settings;
CREATE POLICY ps_admin_update ON platform_settings FOR UPDATE
  USING (is_admin()) WITH CHECK (is_admin());

-- ---------- 4. Admin: suspend / activate a user ----------
CREATE OR REPLACE FUNCTION admin_set_suspended(p_user UUID, p_suspended BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  UPDATE profiles SET is_suspended = p_suspended, updated_at = now() WHERE id = p_user;
END; $$;

-- ---------- 5. Admin: review KYC (verify / reject) ----------
CREATE OR REPLACE FUNCTION admin_set_kyc(p_user UUID, p_status TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  IF p_status NOT IN ('none','pending','verified') THEN
    RAISE EXCEPTION 'Bad kyc_status %', p_status;
  END IF;
  UPDATE profiles SET kyc_status = p_status, updated_at = now() WHERE id = p_user;
END; $$;

GRANT EXECUTE ON FUNCTION is_admin(UUID)                     TO authenticated;
GRANT EXECUTE ON FUNCTION admin_set_suspended(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_set_kyc(UUID, TEXT)          TO authenticated;

-- ---------- 6. Harden withdrawal approve/reject with admin guard ----------
-- Phase 2 defined these without an internal role check (SECURITY DEFINER runs
-- as owner, so any authenticated caller could invoke). Re-declare with guard.
CREATE OR REPLACE FUNCTION approve_withdrawal(p_withdrawal UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  UPDATE withdrawals
    SET status = 'Completed', processed_at = now()
  WHERE id = p_withdrawal AND status = 'Pending';
END; $$;

CREATE OR REPLACE FUNCTION reject_withdrawal(p_withdrawal UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE w RECORD;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  SELECT * INTO w FROM withdrawals WHERE id = p_withdrawal AND status = 'Pending' FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  -- restore the held funds to the owner wallet
  UPDATE profiles SET wallet_balance = wallet_balance + w.amount WHERE id = w.owner_id;
  INSERT INTO transactions (user_id, amount, type, status, reference_id)
  VALUES (w.owner_id, w.amount, 'deposit', 'Completed', 'withdrawal_refund');
  UPDATE withdrawals SET status = 'Rejected', processed_at = now() WHERE id = p_withdrawal;
END; $$;

GRANT EXECUTE ON FUNCTION approve_withdrawal(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_withdrawal(UUID)  TO authenticated;

-- ---------- 7. admin_overview(): single-call dashboard metrics ----------
CREATE OR REPLACE FUNCTION admin_overview()
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE r JSONB;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  SELECT jsonb_build_object(
    'total_users',      (SELECT count(*) FROM profiles),
    'total_riders',     (SELECT count(*) FROM profiles WHERE role = 'Rider'),
    'total_owners',     (SELECT count(*) FROM profiles WHERE role = 'Owner'),
    'suspended_users',  (SELECT count(*) FROM profiles WHERE is_suspended),
    'pending_kyc',      (SELECT count(*) FROM profiles WHERE kyc_status = 'pending'),
    'total_listings',   (SELECT count(*) FROM listings),
    'active_listings',  (SELECT count(*) FROM listings WHERE is_active),
    'total_bookings',   (SELECT count(*) FROM bookings),
    'active_bookings',  (SELECT count(*) FROM bookings WHERE status IN ('Confirmed','Active')),
    'overstays',        (SELECT count(*) FROM bookings WHERE status = 'Overstayed'),
    'pending_withdrawals', (SELECT count(*) FROM withdrawals WHERE status = 'Pending'),
    'gross_volume',     (SELECT COALESCE(sum(total_amount),0) FROM bookings WHERE status IN ('Completed','Active','Confirmed','Overstayed','Refunded')),
    'platform_revenue', (SELECT COALESCE(sum(commission_amount),0) FROM bookings WHERE status = 'Completed'),
    'owner_payouts',    (SELECT COALESCE(sum(owner_earnings),0) FROM bookings WHERE status = 'Completed'),
    'refunded_total',   (SELECT COALESCE(sum(amount),0) FROM transactions WHERE type = 'refund')
  ) INTO r;
  RETURN r;
END; $$;

-- ---------- 8. admin_daily_revenue(days): revenue time series ----------
-- One row per day for the last p_days, gross + commission + booking count.
CREATE OR REPLACE FUNCTION admin_daily_revenue(p_days INT DEFAULT 30)
RETURNS TABLE (day DATE, bookings BIGINT, gross NUMERIC, commission NUMERIC, payouts NUMERIC)
LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  RETURN QUERY
  SELECT d::date AS day,
         COALESCE(b.cnt, 0)        AS bookings,
         COALESCE(b.gross, 0)      AS gross,
         COALESCE(b.commission, 0) AS commission,
         COALESCE(b.payouts, 0)    AS payouts
  FROM generate_series((now()::date - (p_days - 1)), now()::date, interval '1 day') d
  LEFT JOIN (
    SELECT created_at::date AS day,
           count(*)                AS cnt,
           sum(total_amount)       AS gross,
           sum(commission_amount)  AS commission,
           sum(owner_earnings)     AS payouts
    FROM bookings
    WHERE status = 'Completed'
    GROUP BY created_at::date
  ) b ON b.day = d::date
  ORDER BY day;
END; $$;

GRANT EXECUTE ON FUNCTION admin_overview()            TO authenticated;
GRANT EXECUTE ON FUNCTION admin_daily_revenue(INT)    TO authenticated;

