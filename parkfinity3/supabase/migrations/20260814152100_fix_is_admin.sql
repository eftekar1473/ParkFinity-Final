CREATE OR REPLACE FUNCTION public.is_admin(p_uid UUID DEFAULT auth.uid())
RETURNS BOOLEAN LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_uid IS NULL THEN
    RETURN FALSE;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = p_uid AND LOWER(role::text) = 'admin'
  ) OR (
    COALESCE(auth.jwt()->'user_metadata'->>'role', auth.jwt()->'app_metadata'->>'role', '') ILIKE 'admin'
  );
END; $$;

CREATE OR REPLACE FUNCTION public.admin_overview()
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r JSONB;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  SELECT jsonb_build_object(
    'total_users',      (SELECT count(*) FROM public.profiles),
    'total_riders',     (SELECT count(*) FROM public.profiles WHERE LOWER(role::text) = 'rider'),
    'total_owners',     (SELECT count(*) FROM public.profiles WHERE LOWER(role::text) = 'owner'),
    'suspended_users',  (SELECT count(*) FROM public.profiles WHERE is_suspended),
    'pending_kyc',      (SELECT count(*) FROM public.profiles WHERE kyc_status = 'pending'),
    'total_listings',   (SELECT count(*) FROM public.listings),
    'active_listings',  (SELECT count(*) FROM public.listings WHERE is_active),
    'total_bookings',   (SELECT count(*) FROM public.bookings),
    'active_bookings',  (SELECT count(*) FROM public.bookings WHERE status IN ('Confirmed','Active')),
    'overstays',        (SELECT count(*) FROM public.bookings WHERE status = 'Overstayed'),
    'pending_withdrawals', (SELECT count(*) FROM public.withdrawals WHERE status = 'Pending'),
    'gross_volume',     (SELECT COALESCE(sum(total_amount),0) FROM public.bookings WHERE status IN ('Completed','Active','Confirmed','Overstayed','Refunded')),
    'platform_revenue', (SELECT COALESCE(sum(commission_amount),0) FROM public.bookings WHERE status = 'Completed'),
    'owner_payouts',    (SELECT COALESCE(sum(owner_earnings),0) FROM public.bookings WHERE status = 'Completed'),
    'refunded_total',   (SELECT COALESCE(sum(amount),0) FROM public.transactions WHERE type = 'refund')
  ) INTO r;
  RETURN r;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_daily_revenue(p_days INT DEFAULT 30)
RETURNS TABLE (day DATE, bookings BIGINT, gross NUMERIC, commission NUMERIC, payouts NUMERIC)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
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
    FROM public.bookings
    WHERE status = 'Completed'
    GROUP BY created_at::date
  ) b ON b.day = d::date
  ORDER BY day;
END; $$;

GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_overview() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_daily_revenue(INT) TO authenticated, anon;
