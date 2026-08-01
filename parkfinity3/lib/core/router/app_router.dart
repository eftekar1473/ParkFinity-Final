import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth State
import '../../features/auth/data/auth_repository.dart';

// Scaffolds
import 'scaffolds/rider_scaffold.dart';
import 'scaffolds/owner_scaffold.dart';

// Auth Screens
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';

import '../../features/rider/presentation/screens/explore_map_screen.dart';
import '../../features/rider/presentation/screens/rider_booking_history_screen.dart';
import '../../features/rider/presentation/screens/my_vehicles_screen.dart';
import '../../features/rider/presentation/screens/listing_details_screen.dart';
import '../../features/rider/presentation/screens/checkout_screen.dart';
import '../../features/rider/presentation/screens/active_parking_screen.dart';
import '../../features/owner/data/models/listing_model.dart';

// Owner Screens
import '../../features/owner/presentation/screens/owner_dashboard_screen.dart';
import '../../features/owner/presentation/screens/owner_booking_history_screen.dart';
import '../../features/owner/presentation/screens/my_listings_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/owner/presentation/screens/add_listing_screen.dart';

// Shared
import '../../features/shared/presentation/screens/profile_screen.dart';

// Global Navigator Key
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = authState.value?.session;
      final isAuth = session != null;
      final role = session?.user.userMetadata?['role'] as String?;
      
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (authState.isLoading || authState.hasError) return null;

      // Determine where the user should go if they are authenticated
      String? getAuthRedirect() {
        if (role?.toLowerCase() == 'rider') return '/rider/explore';
        if (role?.toLowerCase() == 'owner') return '/owner/dashboard';
        return '/role_selection';
      }

      if (isSplash) {
        return isAuth ? getAuthRedirect() : '/login';
      }

      if (isLoggingIn) {
        return isAuth ? getAuthRedirect() : null;
      }

      if (!isAuth && state.matchedLocation != '/splash') {
        return '/login';
      }

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
        path: '/role_selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/add_listing',
        builder: (context, state) => const AddListingScreen(),
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
});
