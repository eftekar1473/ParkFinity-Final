// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ParkFinity';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get english => 'English';

  @override
  String get bangla => 'বাংলা';

  @override
  String get loginTitle => 'Welcome to ParkFinity';

  @override
  String get loginSubtitle => 'Login to manage or find parking spots.';

  @override
  String get tooManyLoginAttempts =>
      'Too many login attempts. Please wait a moment and try again.';

  @override
  String get tooManySignUpAttempts =>
      'Too many sign-up attempts. Please wait a moment and try again.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get login => 'Login';

  @override
  String get or => 'OR';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get noAccountSignUp => 'Don\'t have an account? Sign Up';

  @override
  String get registerTitle => 'Create an Account';

  @override
  String get registerSubtitle =>
      'Join ParkFinity and solve your parking problems.';

  @override
  String get fullName => 'Full Name';

  @override
  String get signUp => 'Sign Up';

  @override
  String get haveAccountLogin => 'Already have an account? Login';

  @override
  String get chooseYourPath => 'Choose Your Path';

  @override
  String get howWillYouUse => 'How will you use ParkFinity?';

  @override
  String get findParking => 'Find Parking';

  @override
  String get findParkingSub => 'I want to rent parking spots.';

  @override
  String get hostParking => 'Host Parking';

  @override
  String get hostParkingSub => 'I want to earn money hosting spots.';

  @override
  String get verifyIdentity => 'Verify Your Identity';

  @override
  String get kycOwnerIntro =>
      'To host a parking space, upload your NID (both sides) and a property document. We store these securely for fraud protection only — we do not share them.';

  @override
  String get kycRiderIntro =>
      'To book parking, upload your NID (both sides) and your driving license. We store these securely for fraud protection only — we do not share them.';

  @override
  String get nidFront => 'NID — Front Side';

  @override
  String get nidBack => 'NID — Back Side';

  @override
  String get drivingLicense => 'Driving License';

  @override
  String get propertyDocument => 'Property Document';

  @override
  String get addPropertyDoc => 'Add Property Document';

  @override
  String get addAnotherDoc => 'Add Another Document';

  @override
  String get uploadFailed => 'Upload failed:';

  @override
  String get verificationComplete => 'Verification complete!';

  @override
  String get submitContinue => 'Submit & Continue';

  @override
  String get signOut => 'Sign out';

  @override
  String get checkingDocument => 'Checking document…';

  @override
  String get captured => 'Captured ✓';

  @override
  String get tapToCapture => 'Tap to capture';

  @override
  String get myProfile => 'My Profile';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get myVehicles => 'My Vehicles';

  @override
  String get bookingHistory => 'Booking History';

  @override
  String get uploadNid => 'Upload NID';

  @override
  String get uploadLicense => 'Upload Driving License';

  @override
  String get supportAbout => 'Support & About';

  @override
  String get helpCenter => 'Help Center';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get logOut => 'Log Out';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get todaysEarnings => 'Today\'s Earnings';

  @override
  String get activeParkings => 'Active Parkings';

  @override
  String get totalBookingsEver => 'Total Bookings Ever';

  @override
  String get addNewParkingSpot => 'Add New Parking Spot';

  @override
  String get withdrawEarnings => 'Withdraw Earnings';

  @override
  String get welcomeBackOwner => 'Welcome back, Owner!';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get paused => 'Paused';

  @override
  String failedUpdateStatus(String error) {
    return 'Failed to update status: $error';
  }

  @override
  String failedToLoad(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get withdrawalRequested =>
      'Withdrawal requested. Awaiting admin approval.';

  @override
  String get amountBdt => 'Amount (৳)';

  @override
  String get enterValidAmount => 'Enter a valid amount';

  @override
  String get exceedsBalance => 'Exceeds balance';

  @override
  String get myListings => 'My Listings';

  @override
  String get noListings => 'No listings found. Tap + to add one.';

  @override
  String get addParkingSpot => 'Add Parking Spot';

  @override
  String get editListing => 'Edit Listing';

  @override
  String get spotPhotosMin3 => 'Spot Photos (Min 3)';

  @override
  String get addPhotos => 'Add Photos';

  @override
  String get noPhotosSelected => 'No photos selected.';

  @override
  String get spotVideoRequired => 'Spot Video (1 required)';

  @override
  String get addVideo => 'Add Video';

  @override
  String get videoSelected => 'Video selected successfully.';

  @override
  String get noVideoSelected => 'No video selected.';

  @override
  String get spotDetails => 'Spot Details';

  @override
  String get listingTitle => 'Listing Title';

  @override
  String get description => 'Description';

  @override
  String get fullAddress => 'Full Address';

  @override
  String get pricingOptions => 'Pricing Options';

  @override
  String get hourly => 'Hourly';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get amenities => 'Amenities';

  @override
  String get cctvCamera => 'CCTV Camera';

  @override
  String get coveredParking => 'Covered Parking';

  @override
  String get securityGuard => 'Security Guard';

  @override
  String get evCharging => 'EV Charging';

  @override
  String get exactLocation => 'Exact Location';

  @override
  String get searchLocationHint => 'Search location on map...';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get publishListing => 'Publish Listing';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get title => 'Title';

  @override
  String get address => 'Address';

  @override
  String get location => 'Location';

  @override
  String get pricing => 'Pricing';

  @override
  String get withdrawEarningsTitle => 'Withdraw Earnings';

  @override
  String get availableBalance => 'Available Balance';

  @override
  String get amount => 'Amount';

  @override
  String get payoutMethod => 'Payout method / bank details';

  @override
  String get payoutHint => 'bKash 017..., or Bank A/C';

  @override
  String get requestWithdrawal => 'Request Withdrawal';

  @override
  String get history => 'History';

  @override
  String get noWithdrawals => 'No withdrawal requests yet.';

  @override
  String get bookings => 'Bookings';

  @override
  String get myBookings => 'My Bookings';

  @override
  String get noBookings => 'No bookings found.';

  @override
  String get rateThisRider => 'Rate this rider';

  @override
  String get rateThisSpot => 'Rate this spot';

  @override
  String get checkout => 'Checkout';

  @override
  String get selectDuration => 'Select Duration';

  @override
  String get selectVehicle => 'Select Vehicle';

  @override
  String get addVehicleFirst => 'Add a Vehicle First';

  @override
  String get selectYourVehicle => 'Select your vehicle';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get priceBreakdown => 'Price Breakdown';

  @override
  String get peakHourApplied => 'Peak Hour Pricing applied';

  @override
  String get totalAmount => 'Total Amount';

  @override
  String get selectVehicleFirst => 'Please add and select a vehicle first.';

  @override
  String get selectValidVehicle => 'Please select a valid vehicle.';

  @override
  String get noSlotsAvailable => 'No slots available right now.';

  @override
  String get bookingConfirmed => 'Booking confirmed!';

  @override
  String get pay => 'Pay';

  @override
  String get activeSession => 'Active Session';

  @override
  String get noActiveBookings => 'No Active Bookings';

  @override
  String get extendParking => 'Extend Parking';

  @override
  String get duration => 'Duration';

  @override
  String get serverPricesFinal =>
      'Final price is calculated and charged by the server.';

  @override
  String get confirmPay => 'Confirm & Pay';

  @override
  String get extend => 'Extend';

  @override
  String get navigate => 'Navigate';

  @override
  String get cancelBooking => 'Cancel Booking';

  @override
  String get cancelBookingQ => 'Cancel booking?';

  @override
  String get cancelBookingBody =>
      'Your slot will be released. Refunds follow the cancellation policy.';

  @override
  String get keep => 'Keep';

  @override
  String get cancelIt => 'Cancel it';

  @override
  String get couldNotOpenMaps => 'Could not open maps.';

  @override
  String get smartRecommendations => 'Smart Recommendations';

  @override
  String get couldNotLoadRecommendations => 'Could not load recommendations.';

  @override
  String get noMatchingSpots =>
      'No matching spots found. Try adjusting filters.';

  @override
  String get topPick => 'Top Pick';

  @override
  String get availability => 'Availability';

  @override
  String get openingHours => 'Opening hours';

  @override
  String get videoTour => 'Video tour';

  @override
  String get reviews => 'Reviews';

  @override
  String get noReviewsYet => 'No reviews yet. Be the first to book and review!';

  @override
  String get price => 'Price';

  @override
  String get bookNow => 'Book Now';

  @override
  String get full => 'Full';

  @override
  String get askParkfinityAi => 'Ask ParkFinity AI ✨';

  @override
  String get yourPreference => 'Your preference...';

  @override
  String get askAi => 'Ask AI';

  @override
  String get tapToView => 'Tap to view →';

  @override
  String get seeAllRecommendations => 'See all smart recommendations';

  @override
  String get whereToPark => 'Where do you want to park?';

  @override
  String get locationNotFound =>
      'Location not found. Please try another search.';

  @override
  String get addNewVehicle => 'Add New Vehicle';

  @override
  String get vehicleType => 'Vehicle Type';

  @override
  String get brand => 'Brand (e.g., Toyota)';

  @override
  String get model => 'Model (e.g., Corolla)';

  @override
  String get licensePlate => 'License Plate (e.g., Dhaka-Metro-Ga-12-3456)';

  @override
  String get saveVehicle => 'Save Vehicle';

  @override
  String get vehicleAdded => 'Vehicle added successfully!';

  @override
  String get deleteVehicle => 'Delete Vehicle';

  @override
  String get vehicleDeleted => 'Vehicle deleted.';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get addVehicle => 'Add Vehicle';

  @override
  String get noVehicles => 'No vehicles found. Add one below.';

  @override
  String get required => 'Required';

  @override
  String deleteVehicleConfirm(String name) {
    return 'Are you sure you want to delete $name?';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get wallet => 'Wallet';

  @override
  String get explore => 'Explore';

  @override
  String get garage => 'Garage';

  @override
  String get profile => 'Profile';

  @override
  String get error => 'Error';

  @override
  String get upcomingActive => 'Upcoming & Active';

  @override
  String get past => 'Past';

  @override
  String get unknownAddress => 'Unknown Address';

  @override
  String get statusActive => 'Active';

  @override
  String get statusUpcoming => 'Upcoming';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get thisParkingSpot => 'this parking spot';

  @override
  String get thisRider => 'this rider';

  @override
  String riderLabel(String id) {
    return 'Rider $id';
  }

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String get markAllAsRead => 'Mark all as read';

  @override
  String get noNotificationsYet => 'No notifications yet.';

  @override
  String get notification => 'Notification';

  @override
  String get loadingSpots => 'Loading spots…';

  @override
  String get couldNotLoadSpots => 'Could not load spots';

  @override
  String spotsFound(int count) {
    return '$count spots';
  }

  @override
  String get filteredSuffix => ' (filtered)';

  @override
  String get aiPromptHint =>
      'Tell us what kind of parking you need (e.g. \"Cheapest covered spot near Gulshan\")';

  @override
  String aiRecommend(String title) {
    return 'I recommend $title.';
  }

  @override
  String get aiNoMatch => 'Sorry, I could not find a good match.';

  @override
  String get fullNoSlots => 'Full — no free slots';

  @override
  String get freeSpots => 'free';

  @override
  String get newBadge => 'New';

  @override
  String hostedBy(String name) {
    return 'Hosted by $name';
  }

  @override
  String get parkfinityHost => 'ParkFinity host';

  @override
  String joinedIn(String year) {
    return 'Joined $year';
  }

  @override
  String freeOf(int free, int total) {
    return '$free of $total free';
  }

  @override
  String get closed => 'Closed';

  @override
  String get noDescription => 'No description provided for this listing.';

  @override
  String reviewsWithCount(int count) {
    return 'Reviews ($count)';
  }

  @override
  String availableSlotsLabel(int free, int total) {
    return 'Available Slots: $free/$total';
  }

  @override
  String walletBalanceOption(String balance) {
    return 'ParkFinity Wallet (Bal: $balance)';
  }

  @override
  String get onlinePaymentSsl => 'Online Payment (SSLCommerz)';

  @override
  String baseRateLabel(String type) {
    return 'Base Rate ($type)';
  }

  @override
  String get platformFee => 'Platform Fee';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String vehicleNotAllowed(String type) {
    return 'This parking spot does not allow ${type}s.';
  }

  @override
  String get sslUnderConstruction =>
      'Direct SSLCommerz checkout is under construction. Please use your Wallet!';

  @override
  String extendedTo(String time) {
    return 'Extended to $time.';
  }

  @override
  String get timeRemaining => 'Time Remaining';

  @override
  String get expiringSoon => 'Expiring soon!';

  @override
  String get parkingSpot => 'Parking Spot';

  @override
  String get findParkingBtn => 'Find Parking';

  @override
  String get slotsPerVehicleType => 'Slots per Vehicle Type';

  @override
  String get slotsPerVehicleHint =>
      'Set how many spaces each vehicle type can use.';

  @override
  String get addVehicleType => 'Add vehicle type';

  @override
  String get bookingMode => 'Booking Mode';

  @override
  String get instant => 'Instant';

  @override
  String get approve => 'Approve';

  @override
  String get instantHint => 'Riders can book immediately.';

  @override
  String get manualHint =>
      'You approve each booking request before it confirms.';

  @override
  String maxMbPerPhoto(String mb) {
    return 'Max ${mb}MB per photo';
  }

  @override
  String maxMb(String mb) {
    return 'Max ${mb}MB';
  }

  @override
  String photoTooLarge(String name, String mb, String max) {
    return '$name is ${mb}MB — max ${max}MB per photo.';
  }

  @override
  String videoTooLarge(String mb, String max) {
    return 'Video is ${mb}MB — max ${max}MB.';
  }

  @override
  String get min3Photos => 'Please select at least 3 photos.';

  @override
  String get selectOneVideo => 'Please select 1 video.';

  @override
  String get addVehicleTypeSlot =>
      'Add at least one vehicle type with a slot count.';

  @override
  String get uploadingMedia => 'Uploading media... This may take a minute.';

  @override
  String get listingPublished => 'Listing published successfully!';

  @override
  String failedUpload(String error) {
    return 'Failed to upload media or save listing: $error';
  }

  @override
  String get locationPermissionDenied => 'Location permission denied.';

  @override
  String couldNotGetLocation(String error) {
    return 'Could not get your location: $error';
  }

  @override
  String get req => 'Req';

  @override
  String rateBdt(String label) {
    return '$label (৳)';
  }

  @override
  String get myWallet => 'My Wallet';

  @override
  String get addFunds => 'Add Funds';

  @override
  String get fundsAdded => 'Funds added successfully!';

  @override
  String get paymentFailed => 'Payment failed.';

  @override
  String get paymentCancelled => 'Payment cancelled or incomplete.';

  @override
  String get paymentError => 'Payment Error';

  @override
  String get ok => 'OK';

  @override
  String get add => 'Add';

  @override
  String get amountBdtWallet => 'Amount (BDT)';

  @override
  String get transactionHistory => 'Transaction History';

  @override
  String get noTransactions => 'No transactions yet.';
}
