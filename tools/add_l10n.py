# Adds Phase 11-18 keys to app_en.arb / app_bn.arb, preserving order + parity.
import io, json, collections, os

L10N = r'D:\SPL_2\parkfinity3\lib\l10n'

NEW = collections.OrderedDict([
    # profile / auth
    ('phoneNumber',          ('Phone number', 'ফোন নম্বর')),
    ('phoneNumberHelper',    ('Riders and owners use this to call each other', 'রাইডার ও মালিক এই নম্বরে ফোন করবেন')),
    ('editProfileTitle',     ('Edit profile', 'প্রোফাইল এডিট')),
    ('profileUpdated',       ('Profile updated', 'প্রোফাইল হালনাগাদ হয়েছে')),
    ('changePhoto',          ('Change photo', 'ছবি পরিবর্তন')),
    ('verificationStatus',   ('Verification status', 'যাচাই অবস্থা')),
    ('verifiedStatus',       ('Verified', 'যাচাইকৃত')),
    ('pendingStatus',        ('Pending', 'অপেক্ষমাণ')),
    ('notSubmittedStatus',   ('Not submitted', 'জমা দেওয়া হয়নি')),
    ('documentsSubmittedNote', ('Your NID and licence were submitted at sign-up.',
                                'সাইন-আপের সময় আপনার NID ও লাইসেন্স জমা হয়েছে।')),
    ('termsOfService',       ('Terms of Service', 'সেবার শর্তাবলী')),
    ('nameRequired',         ('Name is required', 'নাম দিতে হবে')),
    ('invalidPhone',         ('Enter a valid Bangladeshi mobile number', 'সঠিক বাংলাদেশি মোবাইল নম্বর দিন')),

    # bookings
    ('bookingDetails',       ('Booking details', 'বুকিং বিস্তারিত')),
    ('bookingId',            ('Booking ID', 'বুকিং আইডি')),
    ('upcoming',             ('Upcoming', 'আসন্ন')),
    ('activeTab',            ('Active', 'চলমান')),
    ('completedStatus',      ('Completed', 'সম্পন্ন')),
    ('startTime',            ('Start time', 'শুরুর সময়')),
    ('endTime',              ('End time', 'শেষের সময়')),
    ('pickStartTime',        ('Pick start time', 'শুরুর সময় বাছুন')),
    ('pickEndTime',          ('Pick end time', 'শেষের সময় বাছুন')),
    ('extendBooking',        ('Extend booking', 'সময় বাড়ান')),
    ('paymentBreakdown',     ('Payment breakdown', 'পেমেন্ট বিবরণ')),
    ('baseAmount',           ('Base amount', 'মূল ভাড়া')),
    ('peakSurcharge',        ('Peak hour surcharge', 'পিক আওয়ার চার্জ')),
    ('overstayCharge',       ('Overstay charge', 'অতিরিক্ত সময়ের চার্জ')),
    ('commission',           ('Platform commission', 'প্লাটফর্ম কমিশন')),
    ('totalPaid',            ('Total paid', 'মোট পরিশোধ')),
    ('vehicle',              ('Vehicle', 'যানবাহন')),

    # contact / nav
    ('callRider',            ('Call rider', 'রাইডারকে কল')),
    ('callOwner',            ('Call owner', 'মালিককে কল')),
    ('noPhoneOnFile',        ('No phone number on file', 'ফোন নম্বর নেই')),
    ('couldNotOpenDialer',   ('Could not open the dialer', 'ডায়ালার খোলা যায়নি')),
    ('couldNotOpenMaps',     ('Could not open Google Maps', 'গুগল ম্যাপস খোলা যায়নি')),

    # QR
    ('qrCode',               ('QR code', 'QR কোড')),
    ('spotQrCode',           ('Spot QR code', 'স্পটের QR কোড')),
    ('scanQr',               ('Scan QR', 'QR স্ক্যান')),
    ('scanToStart',          ('Scan the spot QR to start parking', 'পার্কিং শুরু করতে স্পটের QR স্ক্যান করুন')),
    ('scanToEnd',            ('Scan again to end parking', 'পার্কিং শেষ করতে আবার স্ক্যান করুন')),
    ('checkIn',              ('Check in', 'চেক-ইন')),
    ('checkOut',             ('Check out', 'চেক-আউট')),
    ('checkedIn',            ('Checked in', 'চেক-ইন হয়েছে')),
    ('checkedOut',           ('Checked out', 'চেক-আউট হয়েছে')),
    ('enterCodeManually',    ('Enter the 6-character code instead', 'বদলে ৬ অক্ষরের কোড লিখুন')),
    ('shortCode',            ('Short code', 'সংক্ষিপ্ত কোড')),
    ('saveQrImage',          ('Save image', 'ছবি সেভ করুন')),
    ('shareQr',              ('Share / print', 'শেয়ার / প্রিন্ট')),
    ('qrSaved',              ('QR code saved', 'QR কোড সেভ হয়েছে')),
    ('printAndMountQr',      ('Print this and mount it at your parking spot. Riders scan it to start and end parking.',
                              'এটি প্রিন্ট করে আপনার পার্কিং স্পটে লাগান। রাইডাররা এটি স্ক্যান করে পার্কিং শুরু ও শেষ করবেন।')),
    ('cameraPermissionNeeded', ('Camera permission is needed to scan', 'স্ক্যান করতে ক্যামেরার অনুমতি দরকার')),

    # wallet
    ('earnings',             ('Earnings', 'আয়')),
    ('totalEarnings',        ('Total earnings', 'মোট আয়')),
    ('withdraw',             ('Withdraw', 'উইথড্র')),
    ('pendingWithdrawals',   ('Pending withdrawals', 'অপেক্ষমাণ উইথড্র')),
    ('ownerWalletNote',      ('Your booking earnings land here after the Parkfinity commission. Withdraw to your bank account.',
                              'Parkfinity কমিশন বাদ দিয়ে আপনার বুকিং আয় এখানে জমা হয়। ব্যাংক অ্যাকাউন্টে উইথড্র করুন।')),
    ('riderWalletNote',      ('Top up your wallet to book instantly.', 'সাথে সাথে বুক করতে ওয়ালেট রিচার্জ করুন।')),

    # misc UI
    ('photos',               ('Photos', 'ছবি')),
    ('close',                ('Close', 'বন্ধ')),
    ('retry',                ('Retry', 'আবার চেষ্টা')),
    ('save',                 ('Save', 'সেভ')),
    ('loadingLabel',         ('Loading…', 'লোড হচ্ছে…')),
    ('somethingWentWrong',   ('Something went wrong', 'কিছু ভুল হয়েছে')),
    ('searchHint',           ('Search a place', 'জায়গা খুঁজুন')),
    ('yourLocation',         ('Your location', 'আপনার লোকেশন')),
    ('noResults',            ('No results', 'কিছু পাওয়া যায়নি')),
])


def load(path):
    with io.open(path, encoding='utf-8') as f:
        return json.load(f, object_pairs_hook=collections.OrderedDict)


def save(path, data):
    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')


en = load(os.path.join(L10N, 'app_en.arb'))
bn = load(os.path.join(L10N, 'app_bn.arb'))

added = 0
for k, (e, b) in NEW.items():
    if k not in en:
        en[k] = e
        added += 1
    if k not in bn:
        bn[k] = b

# Parity check both directions.
ek = {k for k in en if not k.startswith('@')}
bk = {k for k in bn if not k.startswith('@')}
assert not (ek - bk), 'missing in bn: %s' % sorted(ek - bk)
assert not (bk - ek), 'extra in bn: %s' % sorted(bk - ek)

save(os.path.join(L10N, 'app_en.arb'), en)
save(os.path.join(L10N, 'app_bn.arb'), bn)
print('added %d keys; en=%d bn=%d' % (added, len(ek), len(bk)))
