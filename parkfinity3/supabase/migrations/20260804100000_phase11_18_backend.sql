-- ============================================================
-- Phases 11-18 — one consolidated backend migration
--   11  profile identity (signup trigger, phone, avatar, RPCs)
--   12  QR check-in / check-out
--   13  interval-based availability (replaces counter hold)
--   14  contact phone on listings
--   15  auto payout settlement
--   17  static pages
--   18  notification sweep (reminders)
-- ============================================================

-- ============================================================
-- 11. PROFILE IDENTITY
-- ============================================================

-- Normalize Bangladeshi phone input to +8801XXXXXXXXX. Returns NULL when the
-- input can't be recognised so callers can reject it.
CREATE OR REPLACE FUNCTION normalize_bd_phone(p_raw TEXT)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE d TEXT;
BEGIN
  IF p_raw IS NULL OR btrim(p_raw) = '' THEN RETURN NULL; END IF;
  d := regexp_replace(p_raw, '[^0-9]', '', 'g');
  IF    d ~ '^8801[3-9][0-9]{8}$' THEN RETURN '+' || d;
  ELSIF d ~ '^01[3-9][0-9]{8}$'   THEN RETURN '+88' || d;
  ELSIF d ~ '^1[3-9][0-9]{8}$'    THEN RETURN '+880' || d;
  END IF;
  RETURN NULL;
END; $$;

-- Profile row is created by this trigger on auth.users insert. Google sign-in
-- carries the picture under either avatar_url or picture depending on provider.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone_number, avatar_url, role)
  VALUES (
    new.id,
    new.email,
    COALESCE(NULLIF(new.raw_user_meta_data->>'full_name',''),
             NULLIF(new.raw_user_meta_data->>'name',''),
             split_part(COALESCE(new.email,'user@local'), '@', 1)),
    normalize_bd_phone(new.raw_user_meta_data->>'phone_number'),
    COALESCE(NULLIF(new.raw_user_meta_data->>'avatar_url',''),
             NULLIF(new.raw_user_meta_data->>'picture','')),
    COALESCE(NULLIF(new.raw_user_meta_data->>'role',''), 'Rider')::public.user_role
  )
  ON CONFLICT (id) DO UPDATE SET
    avatar_url   = COALESCE(public.profiles.avatar_url,   EXCLUDED.avatar_url),
    phone_number = COALESCE(public.profiles.phone_number, EXCLUDED.phone_number);
  RETURN new;
END; $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Backfill: users that signed up before the trigger existed, or whose Google
-- avatar/name never landed on the profile row.
INSERT INTO public.profiles (id, email, full_name, avatar_url, role)
SELECT u.id,
       u.email,
       COALESCE(NULLIF(u.raw_user_meta_data->>'full_name',''),
                NULLIF(u.raw_user_meta_data->>'name',''),
                split_part(COALESCE(u.email,'user@local'), '@', 1)),
       COALESCE(NULLIF(u.raw_user_meta_data->>'avatar_url',''),
                NULLIF(u.raw_user_meta_data->>'picture','')),
       COALESCE(NULLIF(u.raw_user_meta_data->>'role',''), 'Rider')::public.user_role
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

UPDATE public.profiles p
SET avatar_url = COALESCE(NULLIF(u.raw_user_meta_data->>'avatar_url',''),
                          NULLIF(u.raw_user_meta_data->>'picture',''))
FROM auth.users u
WHERE u.id = p.id AND p.avatar_url IS NULL;

-- Read own profile in one call (used by the profile header + edit form).
CREATE OR REPLACE FUNCTION my_profile()
RETURNS JSONB LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT to_jsonb(t) FROM (
    SELECT p.id, p.email, p.full_name, p.phone_number, p.avatar_url,
           p.role::text AS role, p.kyc_status, p.wallet_balance,
           p.nid_front_url, p.nid_back_url, p.license_url,
           p.has_payment_due, p.created_at,
           COALESCE((SELECT round(avg(r.rating)::numeric, 2)
                     FROM reviews r WHERE r.reviewee_id = p.id), 0) AS avg_rating,
           COALESCE((SELECT count(*) FROM reviews r WHERE r.reviewee_id = p.id), 0) AS review_count
    FROM profiles p WHERE p.id = auth.uid()
  ) t;
$$;

-- Only the three fields a user is allowed to change. Anything else (wallet,
-- role, kyc) stays server-controlled.
CREATE OR REPLACE FUNCTION update_my_profile(
  p_full_name TEXT DEFAULT NULL,
  p_phone     TEXT DEFAULT NULL,
  p_avatar    TEXT DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_phone TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Not authenticated');
  END IF;

  IF p_phone IS NOT NULL AND btrim(p_phone) <> '' THEN
    v_phone := normalize_bd_phone(p_phone);
    IF v_phone IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'msg', 'Invalid Bangladeshi phone number');
    END IF;
  END IF;

  UPDATE profiles SET
    full_name    = COALESCE(NULLIF(btrim(p_full_name), ''), full_name),
    phone_number = COALESCE(v_phone, phone_number),
    avatar_url   = COALESCE(NULLIF(btrim(p_avatar), ''), avatar_url),
    updated_at   = now()
  WHERE id = auth.uid();

  RETURN jsonb_build_object('ok', true, 'msg', 'Profile updated', 'profile', my_profile());
END; $$;

-- Public-safe view of any user (host card, booking counterpart contact).
CREATE OR REPLACE VIEW public_profiles AS
  SELECT id, full_name, avatar_url, phone_number, role::text AS role, created_at
  FROM profiles;

GRANT SELECT ON public_profiles TO anon, authenticated;
GRANT EXECUTE ON FUNCTION my_profile()                        TO authenticated;
GRANT EXECUTE ON FUNCTION update_my_profile(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION normalize_bd_phone(TEXT)            TO authenticated, service_role;

-- Avatars bucket (public read, own-folder write).
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "avatars public read"  ON storage.objects;
DROP POLICY IF EXISTS "avatars owner write"  ON storage.objects;
DROP POLICY IF EXISTS "avatars owner update" ON storage.objects;
DROP POLICY IF EXISTS "avatars owner delete" ON storage.objects;

CREATE POLICY "avatars public read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "avatars owner write" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');
CREATE POLICY "avatars owner update" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'avatars' AND owner = auth.uid());
CREATE POLICY "avatars owner delete" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'avatars' AND owner = auth.uid());

-- ============================================================
-- 12. QR CHECK-IN / CHECK-OUT
-- ============================================================

ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS qr_token      UUID        NOT NULL DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS qr_short_code TEXT,
  ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(20);

UPDATE listings
SET qr_short_code = upper(substr(replace(qr_token::text, '-', ''), 1, 6))
WHERE qr_short_code IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_listings_qr_token ON listings(qr_token);
CREATE INDEX IF NOT EXISTS idx_listings_qr_short ON listings(qr_short_code);

-- Keep the short code in sync whenever a token is rotated.
CREATE OR REPLACE FUNCTION sync_qr_short_code()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.qr_short_code := upper(substr(replace(NEW.qr_token::text, '-', ''), 1, 6));
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_sync_qr_short_code ON listings;
CREATE TRIGGER trg_sync_qr_short_code
  BEFORE INSERT OR UPDATE OF qr_token ON listings
  FOR EACH ROW EXECUTE FUNCTION sync_qr_short_code();

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS checked_in_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS checked_out_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS check_in_method TEXT,   -- qr|code|manual
  ADD COLUMN IF NOT EXISTS no_show        BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE platform_settings
  ADD COLUMN IF NOT EXISTS checkin_grace_minutes INT NOT NULL DEFAULT 15,
  ADD COLUMN IF NOT EXISTS no_show_minutes       INT NOT NULL DEFAULT 30,
  ADD COLUMN IF NOT EXISTS reminder_minutes      INT NOT NULL DEFAULT 30;

-- Rider scans the printed QR (or types the 6-char code) to start parking.
-- Resolves the caller's own booking on that listing; no booking id needed.
CREATE OR REPLACE FUNCTION check_in(p_token TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_listing UUID;
  v_grace   INT;
  b         RECORD;
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

  SELECT COALESCE(checkin_grace_minutes, 15) INTO v_grace FROM platform_settings LIMIT 1;

  -- Nearest bookable window for this rider at this listing.
  SELECT * INTO b FROM bookings
  WHERE rider_id = auth.uid()
    AND listing_id = v_listing
    AND status IN ('Confirmed','Pending')
    AND checked_in_at IS NULL
    AND now() BETWEEN start_time - make_interval(mins => v_grace) AND end_time
  ORDER BY start_time
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false,
      'msg', 'No active booking for this spot right now');
  END IF;

  UPDATE bookings
  SET checked_in_at = now(),
      check_in_method = CASE WHEN length(btrim(p_token)) > 10 THEN 'qr' ELSE 'code' END,
      status = 'Active',
      no_show = FALSE,
      updated_at = now()
  WHERE id = b.id;

  INSERT INTO notifications (user_id, title, message, type, data)
  VALUES (b.rider_id, 'Parking started',
          'You checked in. Ends ' || to_char(b.end_time AT TIME ZONE 'Asia/Dhaka', 'DD Mon HH24:MI'),
          'booking', jsonb_build_object('booking_id', b.id));

  RETURN jsonb_build_object('ok', true, 'msg', 'Checked in',
                            'booking_id', b.id, 'end_time', b.end_time);
END; $$;

-- Second scan ends parking: charges overstay if late, then settles the owner.
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
    v_hours := ceil(EXTRACT(EPOCH FROM (now() - b.end_time)) / 3600.0);
    v_penalty := ROUND(COALESCE(v_rate, 0) * v_hours * v_mult, 2);
  END IF;

  IF v_penalty > 0 THEN
    SELECT wallet_balance INTO v_bal FROM profiles WHERE id = b.rider_id FOR UPDATE;
    IF COALESCE(v_bal, 0) >= v_penalty THEN
      UPDATE profiles SET wallet_balance = wallet_balance - v_penalty WHERE id = b.rider_id;
      INSERT INTO transactions (user_id, amount, type, status, reference_id)
      VALUES (b.rider_id, v_penalty, 'overstay_charge', 'Completed', b.id);
    ELSE
      UPDATE bookings SET payment_due = v_penalty WHERE id = b.id;
      UPDATE profiles  SET has_payment_due = TRUE  WHERE id = b.rider_id;
    END IF;
    UPDATE bookings SET overstay_amount = v_penalty WHERE id = b.id;

    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (b.rider_id, 'Overstay charge',
            'You parked ' || v_hours || 'h past your booking. Charged ' || v_penalty || ' BDT.',
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

GRANT EXECUTE ON FUNCTION check_in(TEXT)  TO authenticated;
GRANT EXECUTE ON FUNCTION check_out(TEXT) TO authenticated;

-- ============================================================
-- 13. INTERVAL-BASED AVAILABILITY
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_bookings_listing_window
  ON bookings (listing_id, start_time, end_time)
  WHERE status IN ('Pending','Confirmed','Active','Overstayed');

-- How many slots of one vehicle type are free across the whole [start,end)
-- window. A booking only consumes a slot while it overlaps, so the same
-- physical slot is sellable for every other hour of the day.
CREATE OR REPLACE FUNCTION available_qty(
  p_listing UUID, p_vtype TEXT, p_start TIMESTAMPTZ, p_end TIMESTAMPTZ
) RETURNS INT LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_cap  INT;
  v_live BOOLEAN;
  v_used INT;
BEGIN
  SELECT COALESCE((slot_capacity->>p_vtype)::int, 0), is_active
    INTO v_cap, v_live
  FROM listings WHERE id = p_listing;

  IF NOT FOUND OR v_live IS NOT TRUE OR v_cap = 0 THEN RETURN 0; END IF;

  -- Peak concurrency over the window: for every booking boundary inside it,
  -- count how many live bookings cover that instant. Max of those = slots held.
  SELECT COALESCE(MAX(c), 0) INTO v_used FROM (
    SELECT (SELECT COALESCE(SUM(b2.slot_qty), 0)
            FROM bookings b2
            WHERE b2.listing_id = p_listing
              AND b2.vehicle_type = p_vtype
              AND b2.status IN ('Pending','Confirmed','Active','Overstayed')
              AND b2.start_time <= pt.t AND b2.end_time > pt.t) AS c
    FROM (
      SELECT p_start AS t
      UNION
      SELECT b1.start_time FROM bookings b1
      WHERE b1.listing_id = p_listing
        AND b1.vehicle_type = p_vtype
        AND b1.status IN ('Pending','Confirmed','Active','Overstayed')
        AND b1.start_time >= p_start AND b1.start_time < p_end
    ) pt
  ) s;

  RETURN GREATEST(v_cap - v_used, 0);
END; $$;

-- Booking-time guard. Advisory lock serialises concurrent reservations on the
-- same listing+type so two riders can't both pass the check for the last slot.
CREATE OR REPLACE FUNCTION reserve_interval(
  p_listing UUID, p_vtype TEXT, p_qty INT,
  p_start TIMESTAMPTZ, p_end TIMESTAMPTZ
) RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_end <= p_start THEN RETURN FALSE; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_listing::text || ':' || p_vtype, 0));
  RETURN available_qty(p_listing, p_vtype, p_start, p_end) >= GREATEST(p_qty, 1);
END; $$;

-- slot_available is display-only ("free right now") for map markers. Recomputed
-- from bookings so a finished booking frees the spot without an explicit release.
CREATE OR REPLACE FUNCTION refresh_listing_availability(p_listing UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_cap  JSONB;
  v_next JSONB;
  k      TEXT;
  used   INT;
BEGIN
  SELECT slot_capacity INTO v_cap FROM listings WHERE id = p_listing;
  IF v_cap IS NULL THEN RETURN; END IF;

  v_next := '{}'::jsonb;
  FOR k IN SELECT jsonb_object_keys(v_cap) LOOP
    SELECT COALESCE(SUM(slot_qty), 0) INTO used
    FROM bookings
    WHERE listing_id = p_listing
      AND vehicle_type = k
      AND status IN ('Pending','Confirmed','Active','Overstayed')
      AND start_time <= now() AND end_time > now();
    v_next := jsonb_set(v_next, ARRAY[k],
                        to_jsonb(GREATEST(COALESCE((v_cap->>k)::int, 0) - used, 0)));
  END LOOP;

  UPDATE listings
  SET slot_available = v_next,
      available_slots = (SELECT COALESCE(SUM(value::int), 0)
                         FROM jsonb_each_text(v_next))
  WHERE id = p_listing;
END; $$;

CREATE OR REPLACE FUNCTION refresh_all_listing_availability()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n INT := 0; r RECORD;
BEGIN
  FOR r IN SELECT id FROM listings WHERE is_active LOOP
    PERFORM refresh_listing_availability(r.id);
    n := n + 1;
  END LOOP;
  RETURN n;
END; $$;

CREATE OR REPLACE FUNCTION trg_booking_availability()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM refresh_listing_availability(COALESCE(NEW.listing_id, OLD.listing_id));
  RETURN NULL;
END; $$;

DROP TRIGGER IF EXISTS trg_bookings_availability ON bookings;
CREATE TRIGGER trg_bookings_availability
  AFTER INSERT OR UPDATE OF status, start_time, end_time, slot_qty OR DELETE ON bookings
  FOR EACH ROW EXECUTE FUNCTION trg_booking_availability();

-- The counter-hold model is gone: cancel no longer hands a slot back, the
-- interval simply stops overlapping. Keep the function as a harmless no-op so
-- older call sites don't error.
DROP FUNCTION IF EXISTS release_slot(UUID, TEXT, INT);
CREATE OR REPLACE FUNCTION release_slot(p_listing UUID, p_vtype TEXT, p_qty INT DEFAULT 1)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM refresh_listing_availability(p_listing);
  RETURN TRUE;
END; $$;

CREATE OR REPLACE FUNCTION book_slot(p_listing UUID, p_vtype TEXT, p_qty INT DEFAULT 1)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- Legacy entry point: instantaneous availability only. New code must call
  -- reserve_interval so the whole booked window is checked.
  RETURN available_qty(p_listing, p_vtype, now(), now() + interval '1 hour') >= GREATEST(p_qty, 1);
END; $$;

GRANT EXECUTE ON FUNCTION available_qty(UUID, TEXT, TIMESTAMPTZ, TIMESTAMPTZ)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION reserve_interval(UUID, TEXT, INT, TIMESTAMPTZ, TIMESTAMPTZ)
  TO service_role;
GRANT EXECUTE ON FUNCTION refresh_listing_availability(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION refresh_all_listing_availability() TO service_role;

SELECT refresh_all_listing_availability();

-- ============================================================
-- 15. AUTO SETTLEMENT (owner gets paid without admin action)
-- ============================================================

-- Bookings whose window closed and that were never ended by a QR scan still
-- have to pay the owner. Runs on the same sweep as the overstay engine.
CREATE OR REPLACE FUNCTION settle_stale_bookings()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r         RECORD;
  v_settled INT := 0;
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
    PERFORM complete_booking(r.id);   -- owner still earns; spot was held
    v_noshow := v_noshow + 1;
  END LOOP;

  -- Checked in, never checked out, and past the overstay window: settle it.
  FOR r IN
    SELECT id FROM bookings
    WHERE status IN ('Active','Overstayed')
      AND checked_out_at IS NULL
      AND end_time < now() - make_interval(mins => v_ns_min)
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE bookings SET checked_out_at = now() WHERE id = r.id;
    PERFORM complete_booking(r.id);
    v_settled := v_settled + 1;
  END LOOP;

  RETURN jsonb_build_object('settled', v_settled, 'no_show', v_noshow);
END; $$;

GRANT EXECUTE ON FUNCTION settle_stale_bookings() TO service_role;

-- ============================================================
-- 17. STATIC PAGES (help centre, privacy policy, terms)
-- ============================================================

CREATE TABLE IF NOT EXISTS static_pages (
  slug       TEXT PRIMARY KEY,
  title_en   TEXT NOT NULL,
  title_bn   TEXT NOT NULL,
  body_en    TEXT NOT NULL,
  body_bn    TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE static_pages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sp_read ON static_pages;
CREATE POLICY sp_read ON static_pages FOR SELECT USING (true);
GRANT SELECT ON static_pages TO anon, authenticated;

INSERT INTO static_pages (slug, title_en, title_bn, body_en, body_bn) VALUES
('help', 'Help Center', 'সহায়তা কেন্দ্র',
E'**Booking a spot**\nSearch on the map, pick a spot, choose your start and end time, then confirm. Your wallet is charged at confirmation.\n\n**Starting your parking**\nScan the QR code printed at the spot when you arrive. Scan it again when you leave to end parking.\n\n**Overstaying**\nIf you leave after your booked end time, an overstay charge applies for every started hour. Ending on time always costs less.\n\n**Cancelling**\nCancel from Booking Details. Refund depends on how long before start you cancel.\n\n**Payments**\nRiders top up the wallet with SSLCommerz. Owners earn into the same wallet and withdraw to a bank account.\n\n**Contact**\nsupport@parkfinity.app · +880 1700-000000 (9am-9pm)',
E'**স্পট বুকিং**\nম্যাপে খুঁজুন, স্পট বাছুন, শুরু ও শেষ সময় দিন, তারপর নিশ্চিত করুন। নিশ্চিত করার সময়ই ওয়ালেট থেকে টাকা কাটা হবে।\n\n**পার্কিং শুরু**\nস্পটে পৌঁছে সেখানে লাগানো QR কোড স্ক্যান করুন। বের হওয়ার সময় আবার স্ক্যান করলে পার্কিং শেষ হবে।\n\n**সময় পার হলে**\nবুক করা সময়ের পরে বের হলে প্রতি ঘণ্টার জন্য অতিরিক্ত চার্জ যোগ হবে।\n\n**বাতিল**\nবুকিং ডিটেইলস থেকে বাতিল করুন। কত আগে বাতিল করছেন তার উপর রিফান্ড নির্ভর করে।\n\n**পেমেন্ট**\nরাইডার SSLCommerz দিয়ে ওয়ালেট রিচার্জ করেন। মালিক আয় ওয়ালেটে পান এবং ব্যাংকে উইথড্র করেন।\n\n**যোগাযোগ**\nsupport@parkfinity.app · +880 1700-000000 (সকাল ৯টা-রাত ৯টা)'),
('privacy', 'Privacy Policy', 'গোপনীয়তা নীতি',
E'Last updated: August 2026\n\n**What we collect**\nName, email, phone, profile photo, NID and driving licence images for verification, vehicle details, GPS location while the app is open, booking and payment records.\n\n**Why**\nTo verify identity, show nearby spots, process payments, settle owner earnings, and send booking notifications.\n\n**Who sees it**\nThe other party of a booking sees your name, photo and phone so you can contact each other. Verification documents are visible only to Parkfinity admins. Payment data is handled by SSLCommerz.\n\n**Location**\nGPS is used only while you use the map. It is not tracked in the background.\n\n**Retention**\nBooking and payment records are kept for 5 years for accounting. Verification documents are deleted 90 days after account closure.\n\n**Your rights**\nEdit your profile any time, or email support@parkfinity.app to request account and data deletion.',
E'সর্বশেষ হালনাগাদ: আগস্ট ২০২৬\n\n**আমরা যা সংগ্রহ করি**\nনাম, ইমেইল, ফোন, প্রোফাইল ছবি, যাচাইয়ের জন্য NID ও ড্রাইভিং লাইসেন্সের ছবি, গাড়ির তথ্য, অ্যাপ খোলা থাকলে GPS লোকেশন, বুকিং ও পেমেন্ট রেকর্ড।\n\n**কেন**\nপরিচয় যাচাই, কাছের স্পট দেখানো, পেমেন্ট প্রক্রিয়া, মালিকের আয় নিষ্পত্তি এবং বুকিং নোটিফিকেশন পাঠাতে।\n\n**কারা দেখতে পায়**\nবুকিংয়ের অপর পক্ষ আপনার নাম, ছবি ও ফোন দেখতে পান যাতে যোগাযোগ করা যায়। যাচাই ডকুমেন্ট শুধু Parkfinity অ্যাডমিন দেখেন। পেমেন্ট তথ্য SSLCommerz পরিচালনা করে।\n\n**লোকেশন**\nGPS শুধু ম্যাপ ব্যবহারের সময় নেওয়া হয়। ব্যাকগ্রাউন্ডে ট্র্যাক করা হয় না।\n\n**সংরক্ষণ**\nহিসাবের জন্য বুকিং ও পেমেন্ট রেকর্ড ৫ বছর রাখা হয়। অ্যাকাউন্ট বন্ধের ৯০ দিন পর যাচাই ডকুমেন্ট মুছে ফেলা হয়।\n\n**আপনার অধিকার**\nযেকোনো সময় প্রোফাইল এডিট করুন, অথবা অ্যাকাউন্ট ও ডেটা মুছতে support@parkfinity.app এ ইমেইল করুন।'),
('terms', 'Terms of Service', 'সেবার শর্তাবলী',
E'By using Parkfinity you agree to these terms.\n\n**Riders** must hold a valid booking and check in via QR. Overstay charges are automatic and non-negotiable. Damage to the property is the rider''s responsibility.\n\n**Owners** must keep listings accurate, honour confirmed bookings, and print and display the spot QR code. Parkfinity deducts a commission from every booking and pays the remainder to the owner wallet.\n\n**Payments** are in BDT via SSLCommerz. Withdrawals are processed within 3 business days.\n\n**Liability** Parkfinity is a marketplace and is not liable for theft or damage at a parking spot.\n\n**Suspension** Accounts may be suspended for fraud, repeated no-shows, or unpaid dues.',
E'Parkfinity ব্যবহার করলে আপনি এই শর্তে সম্মত হচ্ছেন।\n\n**রাইডার** অবশ্যই বৈধ বুকিং রাখবেন ও QR স্ক্যান করে চেক-ইন করবেন। ওভারস্টে চার্জ স্বয়ংক্রিয়। সম্পত্তির ক্ষতির দায় রাইডারের।\n\n**মালিক** সঠিক তথ্য দেবেন, নিশ্চিত বুকিং রক্ষা করবেন এবং স্পটের QR কোড প্রিন্ট করে লাগাবেন। প্রতিটি বুকিং থেকে Parkfinity কমিশন কেটে বাকি টাকা মালিকের ওয়ালেটে দেয়।\n\n**পেমেন্ট** SSLCommerz এর মাধ্যমে টাকায়। উইথড্র ৩ কর্মদিবসে প্রক্রিয়া হয়।\n\n**দায়** Parkfinity একটি মার্কেটপ্লেস; পার্কিং স্পটে চুরি বা ক্ষতির দায় নেয় না।\n\n**স্থগিত** জালিয়াতি, বারবার অনুপস্থিতি বা বকেয়ার জন্য অ্যাকাউন্ট স্থগিত হতে পারে।')
ON CONFLICT (slug) DO UPDATE SET
  title_en = EXCLUDED.title_en, title_bn = EXCLUDED.title_bn,
  body_en  = EXCLUDED.body_en,  body_bn  = EXCLUDED.body_bn,
  updated_at = now();

-- ============================================================
-- 18. NOTIFICATION SWEEP (reminders + no-show warnings)
-- ============================================================

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ending_soon_sent_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION notification_sweep()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r        RECORD;
  v_lead   INT;
  v_start  INT := 0;
  v_ending INT := 0;
BEGIN
  SELECT COALESCE(reminder_minutes, 30) INTO v_lead FROM platform_settings LIMIT 1;

  -- Starting soon.
  FOR r IN
    SELECT b.id, b.rider_id, b.start_time, l.title
    FROM bookings b JOIN listings l ON l.id = b.listing_id
    WHERE b.status IN ('Pending','Confirmed')
      AND b.reminder_sent_at IS NULL
      AND b.start_time BETWEEN now() AND now() + make_interval(mins => v_lead)
  LOOP
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (r.rider_id, 'Parking starts soon',
            r.title || ' starts at ' || to_char(r.start_time AT TIME ZONE 'Asia/Dhaka', 'HH24:MI') || '. Scan the QR when you arrive.',
            'reminder', jsonb_build_object('booking_id', r.id));
    UPDATE bookings SET reminder_sent_at = now() WHERE id = r.id;
    v_start := v_start + 1;
  END LOOP;

  -- Ending soon — the extend/overstay warning.
  FOR r IN
    SELECT b.id, b.rider_id, b.end_time, l.title
    FROM bookings b JOIN listings l ON l.id = b.listing_id
    WHERE b.status IN ('Confirmed','Active')
      AND b.ending_soon_sent_at IS NULL
      AND b.end_time BETWEEN now() AND now() + interval '15 minutes'
  LOOP
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (r.rider_id, 'Parking ends soon',
            r.title || ' ends at ' || to_char(r.end_time AT TIME ZONE 'Asia/Dhaka', 'HH24:MI') || '. Extend or leave to avoid an overstay charge.',
            'reminder', jsonb_build_object('booking_id', r.id));
    UPDATE bookings SET ending_soon_sent_at = now() WHERE id = r.id;
    v_ending := v_ending + 1;
  END LOOP;

  RETURN jsonb_build_object('starting_soon', v_start, 'ending_soon', v_ending);
END; $$;

GRANT EXECUTE ON FUNCTION notification_sweep() TO service_role;

-- One sweep job runs the whole background pipeline every 5 minutes.
CREATE OR REPLACE FUNCTION parkfinity_sweep()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN jsonb_build_object(
    'overstay',      process_overstays(),
    'settlement',    settle_stale_bookings(),
    'notifications', notification_sweep(),
    'availability',  refresh_all_listing_availability()
  );
END; $$;

GRANT EXECUTE ON FUNCTION parkfinity_sweep() TO service_role;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('overstay-sweep')
      WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'overstay-sweep');
    PERFORM cron.unschedule('parkfinity-sweep')
      WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'parkfinity-sweep');
    PERFORM cron.schedule('parkfinity-sweep', '*/5 * * * *', 'SELECT parkfinity_sweep()');
  END IF;
END $$;
