import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  User? get currentUser => _supabase.auth.currentUser;

  Future<void> signInWithEmail(String email, String password) async {
    late final AuthResponse response;
    try {
      response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      // Surface Supabase auth errors with clear messages.
      if (e.message.toLowerCase().contains('invalid login credentials') ||
          e.message.toLowerCase().contains('invalid_credentials')) {
        throw Exception('Invalid email or password. Please try again.');
      }
      if (e.message.toLowerCase().contains('email not confirmed')) {
        throw Exception(
            'Your email is not confirmed. Please check your inbox '
            'and click the verification link, then try again.');
      }
      throw Exception(e.message);
    }

    // Check role from user_metadata first.
    String? role = response.user?.userMetadata?['role'] as String?;

    // Fallback: check the profiles table if user_metadata doesn't have a role.
    if (role == null || role.trim().isEmpty) {
      try {
        final profile = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', response.user!.id)
            .maybeSingle();
        role = profile?['role'] as String?;
      } catch (_) {
        // If the profiles query fails, proceed with null role.
      }
    }

    if (role?.toLowerCase() != 'admin') {
      await _supabase.auth.signOut();
      throw Exception(
          'Access denied. Only Admin accounts can access this panel.');
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
