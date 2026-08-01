import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client.auth);
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final GoTrueClient _auth;

  AuthRepository(this._auth);

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;
  User? get currentUser => _auth.currentUser;

  Future<AuthResponse> signInWithEmailAndPassword(String email, String password) async {
    return await _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmailAndPassword(String email, String password, String fullName) async {
    return await _auth.signUp(
      email: email, 
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> updateRole(String role) async {
    final user = currentUser;
    if (user != null) {
      await _auth.updateUser(UserAttributes(data: {'role': role}));
      // Also update the public profiles table
      await Supabase.instance.client
          .from('profiles')
          .update({'role': role})
          .eq('id', user.id);
    }
  }

  Future<void> updateDocumentUrl(String column, String url) async {
    final user = currentUser;
    if (user != null) {
      await Supabase.instance.client
          .from('profiles')
          .update({column: url})
          .eq('id', user.id);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
