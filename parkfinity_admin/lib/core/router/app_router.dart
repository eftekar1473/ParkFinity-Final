import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/admin_scaffold.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/users/presentation/screens/users_screen.dart';
import '../../features/listings/presentation/screens/listings_screen.dart';
import '../../features/withdrawals/presentation/screens/withdrawals_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final session = authState.value?.session;
      final isAuth = session != null;
      final role = session?.user.userMetadata?['role'] as String?;
      
      final isLoggingIn = state.matchedLocation == '/login';

      if (authState.isLoading || authState.hasError) return null;

      if (isLoggingIn) {
        if (isAuth && role?.toLowerCase() == 'admin') return '/dashboard';
        return null; // Stay on login
      }

      if (!isAuth) {
        return '/login';
      }

      if (role?.toLowerCase() != 'admin') {
        // Technically this shouldn't happen due to the repo blocking it, but just in case
        return '/login'; 
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AdminScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/listings',
            builder: (context, state) => const ListingsScreen(),
          ),
          GoRoute(
            path: '/withdrawals',
            builder: (context, state) => const WithdrawalsScreen(),
          ),
        ],
      ),
    ],
  );
});
