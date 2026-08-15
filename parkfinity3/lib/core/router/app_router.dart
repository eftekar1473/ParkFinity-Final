import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth State
import '../../features/auth/data/auth_repository.dart';
import '../services/push_service.dart';

// Scaffolds
import 'scaffolds/rider_scaffold.dart';
import 'scaffolds/owner_scaffold.dart';

// Auth Screens
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/presentation/screens/kyc_upload_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/set_new_password_screen.dart';

import '../../features/rider/presentation/screens/explore_map_screen.dart';
import '../../features/rider/presentation/screens/rider_booking_history_screen.dart';
import '../../features/rider/presentation/screens/my_vehicles_screen.dart';
import '../../features/rider/presentation/screens/listing_details_screen.dart';
import '../../features/rider/presentation/screens/checkout_screen.dart';
import '../../features/rider/presentation/screens/active_parking_screen.dart';
import '../../features/rider/presentation/screens/smart_recommendations_screen.dart';
import '../../features/rider/presentation/screens/listings_screen.dart';
import '../../features/owner/data/models/listing_model.dart';

// Owner Screens
import '../../features/owner/presentation/screens/owner_dashboard_screen.dart';
import '../../features/owner/presentation/screens/owner_booking_history_screen.dart';
import '../../features/owner/presentation/screens/my_listings_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/owner/presentation/screens/add_listing_screen.dart';
import '../../features/owner/presentation/screens/edit_listing_screen.dart';
import '../../features/owner/presentation/screens/withdrawal_screen.dart';
import '../../features/owner/presentation/screens/listing_qr_screen.dart';

// Shared
import '../../features/shared/presentation/screens/profile_screen.dart';
import '../../features/shared/presentation/screens/edit_profile_screen.dart';
import '../../features/shared/presentation/screens/static_page_screen.dart';
import '../../features/shared/presentation/screens/notifications_screen.dart';
import '../../features/shared/presentation/screens/booking_details_screen.dart';
import '../../features/parking/presentation/screens/qr_scan_screen.dart';
import '../../shared/data/models/booking_model.dart';

// Global Navigator Key
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = authState.value?.session;
      final isAuth = session != null;
      final role = session?.user.userMetadata?['role'] as String?;
      final kyc = session?.user.userMetadata?['kyc_status'] as String?;

      final isSplash = state.matchedLocation == '/splash';
      final loc = state.matchedLocation;

      // Reachable without a session. Anything else bounces to /login.
      const publicRoutes = {
        '/login',
        '/register',
        '/verify-email',
        '/forgot-password',
        '/reset-password',
        '/splash',
      };
      final isLoggingIn = loc == '/login' || loc == '/register';

      if (authState.isLoading || authState.hasError) return null;

      // A recovery deep link opens a temporary session flagged passwordRecovery.
      // Send the user to set a new password before the normal home redirect,
      // and hold them there until they submit (or the event clears).
      final isRecovery =
          authState.value?.event == AuthChangeEvent.passwordRecovery;
      if (isRecovery) {
        return loc == '/reset-password' ? null : '/reset-password';
      }

      final hasRole = role?.toLowerCase() == 'rider' || role?.toLowerCase() == 'owner';
      final kycOk = kyc == 'verified';

      // Where an authenticated user belongs, enforcing the onboarding order:
      // role selection -> KYC verification -> home.
      String getAuthRedirect() {
        if (!hasRole) return '/role_selection';
        if (!kycOk) return '/kyc';
        return role!.toLowerCase() == 'owner' ? '/owner/dashboard' : '/rider/explore';
      }

      if (!isAuth) {
        // Splash is public but has nothing to show once auth resolved.
        if (isSplash) return '/login';
        return publicRoutes.contains(loc) ? null : '/login';
      }

      // Authenticated below this point.
      if (isSplash || isLoggingIn) return getAuthRedirect();

      // Hold the user on role selection until a role is chosen.
      if (!hasRole) return loc == '/role_selection' ? null : '/role_selection';

      // Hold the user on the KYC gate until verified. Allow sign-out to work.
      if (!kycOk) return loc == '/kyc' ? null : '/kyc';

      // Verified users should not sit on onboarding screens.
      if (loc == '/role_selection' || loc == '/kyc') return getAuthRedirect();

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) =>
            VerifyEmailScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const SetNewPasswordScreen(),
      ),
      GoRoute(
        path: '/role_selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/kyc',
        builder: (context, state) => const KycUploadScreen(),
      ),
      GoRoute(
        path: '/add_listing',
        builder: (context, state) => const AddListingScreen(),
      ),
      GoRoute(
        path: '/edit_listing',
        builder: (context, state) =>
            EditListingScreen(listing: state.extra as ListingModel),
      ),
      GoRoute(
        path: '/withdraw',
        builder: (context, state) => const WithdrawalScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/page/:slug',
        builder: (context, state) =>
            StaticPageScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/listing/qr',
        builder: (context, state) =>
            ListingQrScreen(listing: state.extra as ListingModel),
      ),
      // extra carries the booking; `owner=1` flips the screen to the owner view.
      GoRoute(
        path: '/booking',
        builder: (context, state) => BookingDetailsScreen(
          booking: state.extra as BookingModel,
          asOwner: state.uri.queryParameters['owner'] == '1',
        ),
      ),
      // mode is 'in' or 'out'; anything else is treated as check-in.
      GoRoute(
        path: '/scan/:mode',
        builder: (context, state) => QrScanScreen(
          mode: state.pathParameters['mode'] == 'out'
              ? ScanMode.checkOut
              : ScanMode.checkIn,
        ),
      ),

      GoRoute(
        path: '/active_session',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ActiveParkingScreen(),
      ),

      // ==========================================
      // RIDER NAVIGATION SHELL
      // ==========================================
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return RiderScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rider/explore',
                builder: (context, state) => const ExploreMapScreen(),
                routes: [
                  GoRoute(
                    path: 'details',
                    builder: (context, state) => ListingDetailsScreen(listing: state.extra as ListingModel),
                  ),
                  GoRoute(
                    path: 'checkout',
                    builder: (context, state) => CheckoutScreen(listing: state.extra as ListingModel),
                  ),
                  GoRoute(
                    path: 'active',
                    builder: (context, state) => const ActiveParkingScreen(),
                  ),
                  GoRoute(
                    path: 'recommendations',
                    builder: (context, state) =>
                        const SmartRecommendationsScreen(),
                  ),
                  GoRoute(
                    path: 'listings',
                    builder: (context, state) => const ListingsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rider/bookings',
                builder: (context, state) => const RiderBookingHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rider/garage',
                builder: (context, state) => const MyVehiclesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rider/wallet',
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rider/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'vehicles',
                    builder: (context, state) => const MyVehiclesScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const RiderBookingHistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ==========================================
      // OWNER NAVIGATION SHELL
      // ==========================================
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return OwnerScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/owner/dashboard',
                builder: (context, state) => const OwnerDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/owner/bookings',
                builder: (context, state) => const OwnerBookingHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/owner/listings',
                builder: (context, state) => const MyListingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/owner/wallet',
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/owner/profile',
                builder: (context, state) => const ProfileScreen(), // Shared
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // Let a push tap navigate. Queued inside PushService until this runs.
  PushService.instance.attachNavigator(router.push);

  return router;
});
