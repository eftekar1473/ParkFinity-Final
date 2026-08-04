import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ParkFinity'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @bangla.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get bangla;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to ParkFinity'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Login to manage or find parking spots.'**
  String get loginSubtitle;

  /// No description provided for @tooManyLoginAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many login attempts. Please wait a moment and try again.'**
  String get tooManyLoginAttempts;

  /// No description provided for @tooManySignUpAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many sign-up attempts. Please wait a moment and try again.'**
  String get tooManySignUpAttempts;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @noAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign Up'**
  String get noAccountSignUp;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an Account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join ParkFinity and solve your parking problems.'**
  String get registerSubtitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @haveAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get haveAccountLogin;

  /// No description provided for @chooseYourPath.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Path'**
  String get chooseYourPath;

  /// No description provided for @howWillYouUse.
  ///
  /// In en, this message translates to:
  /// **'How will you use ParkFinity?'**
  String get howWillYouUse;

  /// No description provided for @findParking.
  ///
  /// In en, this message translates to:
  /// **'Find Parking'**
  String get findParking;

  /// No description provided for @findParkingSub.
  ///
  /// In en, this message translates to:
  /// **'I want to rent parking spots.'**
  String get findParkingSub;

  /// No description provided for @hostParking.
  ///
  /// In en, this message translates to:
  /// **'Host Parking'**
  String get hostParking;

  /// No description provided for @hostParkingSub.
  ///
  /// In en, this message translates to:
  /// **'I want to earn money hosting spots.'**
  String get hostParkingSub;

  /// No description provided for @verifyIdentity.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Identity'**
  String get verifyIdentity;

  /// No description provided for @kycOwnerIntro.
  ///
  /// In en, this message translates to:
  /// **'To host a parking space, upload your NID (both sides) and a property document. We store these securely for fraud protection only — we do not share them.'**
  String get kycOwnerIntro;

  /// No description provided for @kycRiderIntro.
  ///
  /// In en, this message translates to:
  /// **'To book parking, upload your NID (both sides) and your driving license. We store these securely for fraud protection only — we do not share them.'**
  String get kycRiderIntro;

  /// No description provided for @nidFront.
  ///
  /// In en, this message translates to:
  /// **'NID — Front Side'**
  String get nidFront;

  /// No description provided for @nidBack.
  ///
  /// In en, this message translates to:
  /// **'NID — Back Side'**
  String get nidBack;

  /// No description provided for @drivingLicense.
  ///
  /// In en, this message translates to:
  /// **'Driving License'**
  String get drivingLicense;

  /// No description provided for @propertyDocument.
  ///
  /// In en, this message translates to:
  /// **'Property Document'**
  String get propertyDocument;

  /// No description provided for @addPropertyDoc.
  ///
  /// In en, this message translates to:
  /// **'Add Property Document'**
  String get addPropertyDoc;

  /// No description provided for @addAnotherDoc.
  ///
  /// In en, this message translates to:
  /// **'Add Another Document'**
  String get addAnotherDoc;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed:'**
  String get uploadFailed;

  /// No description provided for @verificationComplete.
  ///
  /// In en, this message translates to:
  /// **'Verification complete!'**
  String get verificationComplete;

  /// No description provided for @submitContinue.
  ///
  /// In en, this message translates to:
  /// **'Submit & Continue'**
  String get submitContinue;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @checkingDocument.
  ///
  /// In en, this message translates to:
  /// **'Checking document…'**
  String get checkingDocument;

  /// No description provided for @captured.
  ///
  /// In en, this message translates to:
  /// **'Captured ✓'**
  String get captured;

  /// No description provided for @tapToCapture.
  ///
  /// In en, this message translates to:
  /// **'Tap to capture'**
  String get tapToCapture;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @myVehicles.
  ///
  /// In en, this message translates to:
  /// **'My Vehicles'**
  String get myVehicles;

  /// No description provided for @bookingHistory.
  ///
  /// In en, this message translates to:
  /// **'Booking History'**
  String get bookingHistory;

  /// No description provided for @uploadNid.
  ///
  /// In en, this message translates to:
  /// **'Upload NID'**
  String get uploadNid;

  /// No description provided for @uploadLicense.
  ///
  /// In en, this message translates to:
  /// **'Upload Driving License'**
  String get uploadLicense;

  /// No description provided for @supportAbout.
  ///
  /// In en, this message translates to:
  /// **'Support & About'**
  String get supportAbout;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @todaysEarnings.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Earnings'**
  String get todaysEarnings;

  /// No description provided for @activeParkings.
  ///
  /// In en, this message translates to:
  /// **'Active Parkings'**
  String get activeParkings;

  /// No description provided for @totalBookingsEver.
  ///
  /// In en, this message translates to:
  /// **'Total Bookings Ever'**
  String get totalBookingsEver;

  /// No description provided for @addNewParkingSpot.
  ///
  /// In en, this message translates to:
  /// **'Add New Parking Spot'**
  String get addNewParkingSpot;

  /// No description provided for @withdrawEarnings.
  ///
  /// In en, this message translates to:
  /// **'Withdraw Earnings'**
  String get withdrawEarnings;

  /// No description provided for @welcomeBackOwner.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, Owner!'**
  String get welcomeBackOwner;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @failedUpdateStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to update status: {error}'**
  String failedUpdateStatus(String error);

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String failedToLoad(String error);

  /// No description provided for @withdrawalRequested.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal requested. Awaiting admin approval.'**
  String get withdrawalRequested;

  /// No description provided for @amountBdt.
  ///
  /// In en, this message translates to:
  /// **'Amount (৳)'**
  String get amountBdt;

  /// No description provided for @enterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get enterValidAmount;

  /// No description provided for @exceedsBalance.
  ///
  /// In en, this message translates to:
  /// **'Exceeds balance'**
  String get exceedsBalance;

  /// No description provided for @myListings.
  ///
  /// In en, this message translates to:
  /// **'My Listings'**
  String get myListings;

  /// No description provided for @noListings.
  ///
  /// In en, this message translates to:
  /// **'No listings found. Tap + to add one.'**
  String get noListings;

  /// No description provided for @addParkingSpot.
  ///
  /// In en, this message translates to:
  /// **'Add Parking Spot'**
  String get addParkingSpot;

  /// No description provided for @editListing.
  ///
  /// In en, this message translates to:
  /// **'Edit Listing'**
  String get editListing;

  /// No description provided for @spotPhotosMin3.
  ///
  /// In en, this message translates to:
  /// **'Spot Photos (Min 3)'**
  String get spotPhotosMin3;

  /// No description provided for @addPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add Photos'**
  String get addPhotos;

  /// No description provided for @noPhotosSelected.
  ///
  /// In en, this message translates to:
  /// **'No photos selected.'**
  String get noPhotosSelected;

  /// No description provided for @spotVideoRequired.
  ///
  /// In en, this message translates to:
  /// **'Spot Video (1 required)'**
  String get spotVideoRequired;

  /// No description provided for @addVideo.
  ///
  /// In en, this message translates to:
  /// **'Add Video'**
  String get addVideo;

  /// No description provided for @videoSelected.
  ///
  /// In en, this message translates to:
  /// **'Video selected successfully.'**
  String get videoSelected;

  /// No description provided for @noVideoSelected.
  ///
  /// In en, this message translates to:
  /// **'No video selected.'**
  String get noVideoSelected;

  /// No description provided for @spotDetails.
  ///
  /// In en, this message translates to:
  /// **'Spot Details'**
  String get spotDetails;

  /// No description provided for @listingTitle.
  ///
  /// In en, this message translates to:
  /// **'Listing Title'**
  String get listingTitle;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @fullAddress.
  ///
  /// In en, this message translates to:
  /// **'Full Address'**
  String get fullAddress;

  /// No description provided for @pricingOptions.
  ///
  /// In en, this message translates to:
  /// **'Pricing Options'**
  String get pricingOptions;

  /// No description provided for @hourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get hourly;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @amenities.
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get amenities;

  /// No description provided for @cctvCamera.
  ///
  /// In en, this message translates to:
  /// **'CCTV Camera'**
  String get cctvCamera;

  /// No description provided for @coveredParking.
  ///
  /// In en, this message translates to:
  /// **'Covered Parking'**
  String get coveredParking;

  /// No description provided for @securityGuard.
  ///
  /// In en, this message translates to:
  /// **'Security Guard'**
  String get securityGuard;

  /// No description provided for @evCharging.
  ///
  /// In en, this message translates to:
  /// **'EV Charging'**
  String get evCharging;

  /// No description provided for @exactLocation.
  ///
  /// In en, this message translates to:
  /// **'Exact Location'**
  String get exactLocation;

  /// No description provided for @searchLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Search location on map...'**
  String get searchLocationHint;

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @publishListing.
  ///
  /// In en, this message translates to:
  /// **'Publish Listing'**
  String get publishListing;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @pricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get pricing;

  /// No description provided for @withdrawEarningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw Earnings'**
  String get withdrawEarningsTitle;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available Balance'**
  String get availableBalance;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @payoutMethod.
  ///
  /// In en, this message translates to:
  /// **'Payout method / bank details'**
  String get payoutMethod;

  /// No description provided for @payoutHint.
  ///
  /// In en, this message translates to:
  /// **'bKash 017..., or Bank A/C'**
  String get payoutHint;

  /// No description provided for @requestWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Request Withdrawal'**
  String get requestWithdrawal;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @noWithdrawals.
  ///
  /// In en, this message translates to:
  /// **'No withdrawal requests yet.'**
  String get noWithdrawals;

  /// No description provided for @bookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get bookings;

  /// No description provided for @myBookings.
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get myBookings;

  /// No description provided for @noBookings.
  ///
  /// In en, this message translates to:
  /// **'No bookings found.'**
  String get noBookings;

  /// No description provided for @rateThisRider.
  ///
  /// In en, this message translates to:
  /// **'Rate this rider'**
  String get rateThisRider;

  /// No description provided for @rateThisSpot.
  ///
  /// In en, this message translates to:
  /// **'Rate this spot'**
  String get rateThisSpot;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @selectDuration.
  ///
  /// In en, this message translates to:
  /// **'Select Duration'**
  String get selectDuration;

  /// No description provided for @selectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select Vehicle'**
  String get selectVehicle;

  /// No description provided for @addVehicleFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a Vehicle First'**
  String get addVehicleFirst;

  /// No description provided for @selectYourVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select your vehicle'**
  String get selectYourVehicle;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @priceBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Price Breakdown'**
  String get priceBreakdown;

  /// No description provided for @peakHourApplied.
  ///
  /// In en, this message translates to:
  /// **'Peak Hour Pricing applied'**
  String get peakHourApplied;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @selectVehicleFirst.
  ///
  /// In en, this message translates to:
  /// **'Please add and select a vehicle first.'**
  String get selectVehicleFirst;

  /// No description provided for @selectValidVehicle.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid vehicle.'**
  String get selectValidVehicle;

  /// No description provided for @noSlotsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No slots available right now.'**
  String get noSlotsAvailable;

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed!'**
  String get bookingConfirmed;

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @activeSession.
  ///
  /// In en, this message translates to:
  /// **'Active Session'**
  String get activeSession;

  /// No description provided for @noActiveBookings.
  ///
  /// In en, this message translates to:
  /// **'No Active Bookings'**
  String get noActiveBookings;

  /// No description provided for @extendParking.
  ///
  /// In en, this message translates to:
  /// **'Extend Parking'**
  String get extendParking;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @serverPricesFinal.
  ///
  /// In en, this message translates to:
  /// **'Final price is calculated and charged by the server.'**
  String get serverPricesFinal;

  /// No description provided for @confirmPay.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Pay'**
  String get confirmPay;

  /// No description provided for @extend.
  ///
  /// In en, this message translates to:
  /// **'Extend'**
  String get extend;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @cancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get cancelBooking;

  /// No description provided for @cancelBookingQ.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking?'**
  String get cancelBookingQ;

  /// No description provided for @cancelBookingBody.
  ///
  /// In en, this message translates to:
  /// **'Your slot will be released. Refunds follow the cancellation policy.'**
  String get cancelBookingBody;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @cancelIt.
  ///
  /// In en, this message translates to:
  /// **'Cancel it'**
  String get cancelIt;

  /// No description provided for @couldNotOpenMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not open maps.'**
  String get couldNotOpenMaps;

  /// No description provided for @smartRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Smart Recommendations'**
  String get smartRecommendations;

  /// No description provided for @couldNotLoadRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Could not load recommendations.'**
  String get couldNotLoadRecommendations;

  /// No description provided for @noMatchingSpots.
  ///
  /// In en, this message translates to:
  /// **'No matching spots found. Try adjusting filters.'**
  String get noMatchingSpots;

  /// No description provided for @topPick.
  ///
  /// In en, this message translates to:
  /// **'Top Pick'**
  String get topPick;

  /// No description provided for @availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availability;

  /// No description provided for @openingHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get openingHours;

  /// No description provided for @videoTour.
  ///
  /// In en, this message translates to:
  /// **'Video tour'**
  String get videoTour;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet. Be the first to book and review!'**
  String get noReviewsYet;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNow;

  /// No description provided for @full.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get full;

  /// No description provided for @askParkfinityAi.
  ///
  /// In en, this message translates to:
  /// **'Ask ParkFinity AI ✨'**
  String get askParkfinityAi;

  /// No description provided for @yourPreference.
  ///
  /// In en, this message translates to:
  /// **'Your preference...'**
  String get yourPreference;

  /// No description provided for @askAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get askAi;

  /// No description provided for @tapToView.
  ///
  /// In en, this message translates to:
  /// **'Tap to view →'**
  String get tapToView;

  /// No description provided for @seeAllRecommendations.
  ///
  /// In en, this message translates to:
  /// **'See all smart recommendations'**
  String get seeAllRecommendations;

  /// No description provided for @whereToPark.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to park?'**
  String get whereToPark;

  /// No description provided for @locationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Location not found. Please try another search.'**
  String get locationNotFound;

  /// No description provided for @addNewVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add New Vehicle'**
  String get addNewVehicle;

  /// No description provided for @vehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get vehicleType;

  /// No description provided for @brand.
  ///
  /// In en, this message translates to:
  /// **'Brand (e.g., Toyota)'**
  String get brand;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model (e.g., Corolla)'**
  String get model;

  /// No description provided for @licensePlate.
  ///
  /// In en, this message translates to:
  /// **'License Plate (e.g., Dhaka-Metro-Ga-12-3456)'**
  String get licensePlate;

  /// No description provided for @saveVehicle.
  ///
  /// In en, this message translates to:
  /// **'Save Vehicle'**
  String get saveVehicle;

  /// No description provided for @vehicleAdded.
  ///
  /// In en, this message translates to:
  /// **'Vehicle added successfully!'**
  String get vehicleAdded;

  /// No description provided for @deleteVehicle.
  ///
  /// In en, this message translates to:
  /// **'Delete Vehicle'**
  String get deleteVehicle;

  /// No description provided for @vehicleDeleted.
  ///
  /// In en, this message translates to:
  /// **'Vehicle deleted.'**
  String get vehicleDeleted;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add Vehicle'**
  String get addVehicle;

  /// No description provided for @noVehicles.
  ///
  /// In en, this message translates to:
  /// **'No vehicles found. Add one below.'**
  String get noVehicles;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @deleteVehicleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}?'**
  String deleteVehicleConfirm(String name);

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @garage.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get garage;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @upcomingActive.
  ///
  /// In en, this message translates to:
  /// **'Upcoming & Active'**
  String get upcomingActive;

  /// No description provided for @past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No description provided for @unknownAddress.
  ///
  /// In en, this message translates to:
  /// **'Unknown Address'**
  String get unknownAddress;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get statusUpcoming;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @thisParkingSpot.
  ///
  /// In en, this message translates to:
  /// **'this parking spot'**
  String get thisParkingSpot;

  /// No description provided for @thisRider.
  ///
  /// In en, this message translates to:
  /// **'this rider'**
  String get thisRider;

  /// No description provided for @riderLabel.
  ///
  /// In en, this message translates to:
  /// **'Rider {id}'**
  String riderLabel(String id);

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// No description provided for @markAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllAsRead;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get noNotificationsYet;

  /// No description provided for @notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notification;

  /// No description provided for @loadingSpots.
  ///
  /// In en, this message translates to:
  /// **'Loading spots…'**
  String get loadingSpots;

  /// No description provided for @couldNotLoadSpots.
  ///
  /// In en, this message translates to:
  /// **'Could not load spots'**
  String get couldNotLoadSpots;

  /// No description provided for @spotsFound.
  ///
  /// In en, this message translates to:
  /// **'{count} spots'**
  String spotsFound(int count);

  /// No description provided for @filteredSuffix.
  ///
  /// In en, this message translates to:
  /// **' (filtered)'**
  String get filteredSuffix;

  /// No description provided for @aiPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what kind of parking you need (e.g. \"Cheapest covered spot near Gulshan\")'**
  String get aiPromptHint;

  /// No description provided for @aiRecommend.
  ///
  /// In en, this message translates to:
  /// **'I recommend {title}.'**
  String aiRecommend(String title);

  /// No description provided for @aiNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I could not find a good match.'**
  String get aiNoMatch;

  /// No description provided for @fullNoSlots.
  ///
  /// In en, this message translates to:
  /// **'Full — no free slots'**
  String get fullNoSlots;

  /// No description provided for @freeSpots.
  ///
  /// In en, this message translates to:
  /// **'free'**
  String get freeSpots;

  /// No description provided for @newBadge.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newBadge;

  /// No description provided for @hostedBy.
  ///
  /// In en, this message translates to:
  /// **'Hosted by {name}'**
  String hostedBy(String name);

  /// No description provided for @parkfinityHost.
  ///
  /// In en, this message translates to:
  /// **'ParkFinity host'**
  String get parkfinityHost;

  /// No description provided for @joinedIn.
  ///
  /// In en, this message translates to:
  /// **'Joined {year}'**
  String joinedIn(String year);

  /// No description provided for @freeOf.
  ///
  /// In en, this message translates to:
  /// **'{free} of {total} free'**
  String freeOf(int free, int total);

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @anyValue.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get anyValue;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @maxPricePerHour.
  ///
  /// In en, this message translates to:
  /// **'Max price / hour'**
  String get maxPricePerHour;

  /// No description provided for @minimumRating.
  ///
  /// In en, this message translates to:
  /// **'Minimum rating'**
  String get minimumRating;

  /// No description provided for @onSiteSecurity.
  ///
  /// In en, this message translates to:
  /// **'On-site security'**
  String get onSiteSecurity;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Apply 1 filter} other{Apply {count} filters}}'**
  String applyFilters(int count);

  /// No description provided for @availabilitySchedule.
  ///
  /// In en, this message translates to:
  /// **'Availability Schedule'**
  String get availabilitySchedule;

  /// No description provided for @securePayment.
  ///
  /// In en, this message translates to:
  /// **'Secure Payment'**
  String get securePayment;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get submitReview;

  /// No description provided for @addCommentOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a comment (optional)'**
  String get addCommentOptional;

  /// No description provided for @rateTarget.
  ///
  /// In en, this message translates to:
  /// **'Rate {target}'**
  String rateTarget(String target);

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description provided for this listing.'**
  String get noDescription;

  /// No description provided for @reviewsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Reviews ({count})'**
  String reviewsWithCount(int count);

  /// No description provided for @availableSlotsLabel.
  ///
  /// In en, this message translates to:
  /// **'Available Slots: {free}/{total}'**
  String availableSlotsLabel(int free, int total);

  /// No description provided for @walletBalanceOption.
  ///
  /// In en, this message translates to:
  /// **'ParkFinity Wallet (Bal: {balance})'**
  String walletBalanceOption(String balance);

  /// No description provided for @onlinePaymentSsl.
  ///
  /// In en, this message translates to:
  /// **'Online Payment (SSLCommerz)'**
  String get onlinePaymentSsl;

  /// No description provided for @baseRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Base Rate ({type})'**
  String baseRateLabel(String type);

  /// No description provided for @platformFee.
  ///
  /// In en, this message translates to:
  /// **'Platform Fee'**
  String get platformFee;

  /// No description provided for @payAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// No description provided for @vehicleNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This parking spot does not allow {type}s.'**
  String vehicleNotAllowed(String type);

  /// No description provided for @sslUnderConstruction.
  ///
  /// In en, this message translates to:
  /// **'Direct SSLCommerz checkout is under construction. Please use your Wallet!'**
  String get sslUnderConstruction;

  /// No description provided for @extendedTo.
  ///
  /// In en, this message translates to:
  /// **'Extended to {time}.'**
  String extendedTo(String time);

  /// No description provided for @timeRemaining.
  ///
  /// In en, this message translates to:
  /// **'Time Remaining'**
  String get timeRemaining;

  /// No description provided for @expiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon!'**
  String get expiringSoon;

  /// No description provided for @parkingSpot.
  ///
  /// In en, this message translates to:
  /// **'Parking Spot'**
  String get parkingSpot;

  /// No description provided for @findParkingBtn.
  ///
  /// In en, this message translates to:
  /// **'Find Parking'**
  String get findParkingBtn;

  /// No description provided for @slotsPerVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Slots per Vehicle Type'**
  String get slotsPerVehicleType;

  /// No description provided for @slotsPerVehicleHint.
  ///
  /// In en, this message translates to:
  /// **'Set how many spaces each vehicle type can use.'**
  String get slotsPerVehicleHint;

  /// No description provided for @addVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle type'**
  String get addVehicleType;

  /// No description provided for @bookingMode.
  ///
  /// In en, this message translates to:
  /// **'Booking Mode'**
  String get bookingMode;

  /// No description provided for @instant.
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get instant;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @instantHint.
  ///
  /// In en, this message translates to:
  /// **'Riders can book immediately.'**
  String get instantHint;

  /// No description provided for @manualHint.
  ///
  /// In en, this message translates to:
  /// **'You approve each booking request before it confirms.'**
  String get manualHint;

  /// No description provided for @maxMbPerPhoto.
  ///
  /// In en, this message translates to:
  /// **'Max {mb}MB per photo'**
  String maxMbPerPhoto(String mb);

  /// No description provided for @maxMb.
  ///
  /// In en, this message translates to:
  /// **'Max {mb}MB'**
  String maxMb(String mb);

  /// No description provided for @photoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'{name} is {mb}MB — max {max}MB per photo.'**
  String photoTooLarge(String name, String mb, String max);

  /// No description provided for @videoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Video is {mb}MB — max {max}MB.'**
  String videoTooLarge(String mb, String max);

  /// No description provided for @min3Photos.
  ///
  /// In en, this message translates to:
  /// **'Please select at least 3 photos.'**
  String get min3Photos;

  /// No description provided for @selectOneVideo.
  ///
  /// In en, this message translates to:
  /// **'Please select 1 video.'**
  String get selectOneVideo;

  /// No description provided for @addVehicleTypeSlot.
  ///
  /// In en, this message translates to:
  /// **'Add at least one vehicle type with a slot count.'**
  String get addVehicleTypeSlot;

  /// No description provided for @uploadingMedia.
  ///
  /// In en, this message translates to:
  /// **'Uploading media... This may take a minute.'**
  String get uploadingMedia;

  /// No description provided for @listingPublished.
  ///
  /// In en, this message translates to:
  /// **'Listing published successfully!'**
  String get listingPublished;

  /// No description provided for @failedUpload.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload media or save listing: {error}'**
  String failedUpload(String error);

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get locationPermissionDenied;

  /// No description provided for @couldNotGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location: {error}'**
  String couldNotGetLocation(String error);

  /// No description provided for @req.
  ///
  /// In en, this message translates to:
  /// **'Req'**
  String get req;

  /// No description provided for @rateBdt.
  ///
  /// In en, this message translates to:
  /// **'{label} (৳)'**
  String rateBdt(String label);

  /// No description provided for @myWallet.
  ///
  /// In en, this message translates to:
  /// **'My Wallet'**
  String get myWallet;

  /// No description provided for @addFunds.
  ///
  /// In en, this message translates to:
  /// **'Add Funds'**
  String get addFunds;

  /// No description provided for @fundsAdded.
  ///
  /// In en, this message translates to:
  /// **'Funds added successfully!'**
  String get fundsAdded;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed.'**
  String get paymentFailed;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled or incomplete.'**
  String get paymentCancelled;

  /// No description provided for @paymentError.
  ///
  /// In en, this message translates to:
  /// **'Payment Error'**
  String get paymentError;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @amountBdtWallet.
  ///
  /// In en, this message translates to:
  /// **'Amount (BDT)'**
  String get amountBdtWallet;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get noTransactions;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @phoneNumberHelper.
  ///
  /// In en, this message translates to:
  /// **'Riders and owners use this to call each other'**
  String get phoneNumberHelper;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileTitle;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @verificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Verification status'**
  String get verificationStatus;

  /// No description provided for @verifiedStatus.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedStatus;

  /// No description provided for @pendingStatus.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingStatus;

  /// No description provided for @notSubmittedStatus.
  ///
  /// In en, this message translates to:
  /// **'Not submitted'**
  String get notSubmittedStatus;

  /// No description provided for @documentsSubmittedNote.
  ///
  /// In en, this message translates to:
  /// **'Your NID and licence were submitted at sign-up.'**
  String get documentsSubmittedNote;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Bangladeshi mobile number'**
  String get invalidPhone;

  /// No description provided for @bookingDetails.
  ///
  /// In en, this message translates to:
  /// **'Booking details'**
  String get bookingDetails;

  /// No description provided for @bookingId.
  ///
  /// In en, this message translates to:
  /// **'Booking ID'**
  String get bookingId;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @activeTab.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeTab;

  /// No description provided for @completedStatus.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedStatus;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTime;

  /// No description provided for @pickStartTime.
  ///
  /// In en, this message translates to:
  /// **'Pick start time'**
  String get pickStartTime;

  /// No description provided for @pickEndTime.
  ///
  /// In en, this message translates to:
  /// **'Pick end time'**
  String get pickEndTime;

  /// No description provided for @extendBooking.
  ///
  /// In en, this message translates to:
  /// **'Extend booking'**
  String get extendBooking;

  /// No description provided for @paymentBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Payment breakdown'**
  String get paymentBreakdown;

  /// No description provided for @baseAmount.
  ///
  /// In en, this message translates to:
  /// **'Base amount'**
  String get baseAmount;

  /// No description provided for @peakSurcharge.
  ///
  /// In en, this message translates to:
  /// **'Peak hour surcharge'**
  String get peakSurcharge;

  /// No description provided for @overstayCharge.
  ///
  /// In en, this message translates to:
  /// **'Overstay charge'**
  String get overstayCharge;

  /// No description provided for @commission.
  ///
  /// In en, this message translates to:
  /// **'Platform commission'**
  String get commission;

  /// No description provided for @totalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total paid'**
  String get totalPaid;

  /// No description provided for @vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// No description provided for @callRider.
  ///
  /// In en, this message translates to:
  /// **'Call rider'**
  String get callRider;

  /// No description provided for @callOwner.
  ///
  /// In en, this message translates to:
  /// **'Call owner'**
  String get callOwner;

  /// No description provided for @noPhoneOnFile.
  ///
  /// In en, this message translates to:
  /// **'No phone number on file'**
  String get noPhoneOnFile;

  /// No description provided for @couldNotOpenDialer.
  ///
  /// In en, this message translates to:
  /// **'Could not open the dialer'**
  String get couldNotOpenDialer;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get qrCode;

  /// No description provided for @spotQrCode.
  ///
  /// In en, this message translates to:
  /// **'Spot QR code'**
  String get spotQrCode;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQr;

  /// No description provided for @scanToStart.
  ///
  /// In en, this message translates to:
  /// **'Scan the spot QR to start parking'**
  String get scanToStart;

  /// No description provided for @scanToEnd.
  ///
  /// In en, this message translates to:
  /// **'Scan again to end parking'**
  String get scanToEnd;

  /// No description provided for @checkIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get checkIn;

  /// No description provided for @checkOut.
  ///
  /// In en, this message translates to:
  /// **'Check out'**
  String get checkOut;

  /// No description provided for @checkedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get checkedIn;

  /// No description provided for @checkedOut.
  ///
  /// In en, this message translates to:
  /// **'Checked out'**
  String get checkedOut;

  /// No description provided for @enterCodeManually.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-character code instead'**
  String get enterCodeManually;

  /// No description provided for @shortCode.
  ///
  /// In en, this message translates to:
  /// **'Short code'**
  String get shortCode;

  /// No description provided for @saveQrImage.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get saveQrImage;

  /// No description provided for @shareQr.
  ///
  /// In en, this message translates to:
  /// **'Share / print'**
  String get shareQr;

  /// No description provided for @qrSaved.
  ///
  /// In en, this message translates to:
  /// **'QR code saved'**
  String get qrSaved;

  /// No description provided for @printAndMountQr.
  ///
  /// In en, this message translates to:
  /// **'Print this and mount it at your parking spot. Riders scan it to start and end parking.'**
  String get printAndMountQr;

  /// No description provided for @cameraPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is needed to scan'**
  String get cameraPermissionNeeded;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @totalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Total earnings'**
  String get totalEarnings;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @pendingWithdrawals.
  ///
  /// In en, this message translates to:
  /// **'Pending withdrawals'**
  String get pendingWithdrawals;

  /// No description provided for @ownerWalletNote.
  ///
  /// In en, this message translates to:
  /// **'Your booking earnings land here after the Parkfinity commission. Withdraw to your bank account.'**
  String get ownerWalletNote;

  /// No description provided for @riderWalletNote.
  ///
  /// In en, this message translates to:
  /// **'Top up your wallet to book instantly.'**
  String get riderWalletNote;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingLabel;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a place'**
  String get searchHint;

  /// No description provided for @yourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get yourLocation;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
