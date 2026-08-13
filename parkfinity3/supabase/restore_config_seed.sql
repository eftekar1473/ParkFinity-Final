-- Restore config/seed rows wiped by the TRUNCATE.
-- Safe to re-run (idempotent via ON CONFLICT).
-- Run against the linked remote DB.

-- ---------- platform_settings: single config row (defaults) ----------
INSERT INTO platform_settings (id) VALUES (TRUE) ON CONFLICT (id) DO NOTHING;

-- ---------- app_config: single row. functions_url + service_role_key
-- are secrets set manually after deploy, NOT in migrations. The INSERT
-- creates the row and sets functions_url. service_role_key stays NULL here
-- and MUST be pasted manually (Dashboard → Settings → API → service_role key),
-- otherwise push-notification dispatch stays disabled.
INSERT INTO app_config (id) VALUES (TRUE) ON CONFLICT (id) DO NOTHING;

UPDATE app_config SET
  functions_url = 'https://rkqduzjkkyplceipydir.functions.supabase.co'
WHERE id = TRUE;

-- ---------- static_pages: help / privacy / terms ----------
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
