import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/push_service.dart';

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

  /// KYC status pulled synchronously from the JWT metadata (none|pending|verified).
  String get kycStatus =>
      (currentUser?.userMetadata?['kyc_status'] as String?) ?? 'none';

  Future<AuthResponse> signInWithEmailAndPassword(String email, String password) async {
    final res = await _auth.signInWithPassword(email: email, password: password);
    await PushService.instance.registerToken();
    return res;
  }

  Future<AuthResponse> signUpWithEmailAndPassword(
    String email,
    String password,
    String fullName, {
    String? phoneNumber,
  }) async {
    final res = await _auth.signUp(
      email: email,
      password: password,
      // handle_new_user() reads these to build the profiles row.
      data: {
        'full_name': fullName,
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phone_number': phoneNumber.trim(),
      },
    );
    await PushService.instance.registerToken();
    return res;
  }

  /// Native Google sign-in → Supabase via ID token.
  ///
  /// Requires OAuth client IDs (Google Cloud Console) supplied via .env:
  ///   GOOGLE_WEB_CLIENT_ID  (the "Web" OAuth client — used as serverClientId)
  ///   GOOGLE_IOS_CLIENT_ID  (iOS only, optional)
  /// and the Google provider enabled in the Supabase dashboard.
  Future<AuthResponse> signInWithGoogle() async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];

    if (webClientId == null || webClientId.trim().isEmpty) {
      throw const AuthException(
          'Google sign-in is not configured (GOOGLE_WEB_CLIENT_ID missing).');
    }

    final googleSignIn = GoogleSignIn(
      clientId: iosClientId,
      serverClientId: webClientId,
    );
    // Force the account chooser instead of silently reusing a stale account,
    // which is what made the picker appear and then do nothing.
    await googleSignIn.signOut();

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthException('Google sign-in was cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null) {
      throw const AuthException(
          'Google returned no ID token. Check that GOOGLE_WEB_CLIENT_ID is the '
          'Web OAuth client and that this build\'s SHA-1 is registered.');
    }
    final res = await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    await PushService.instance.registerToken();
    return res;
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
      // Refresh so the JWT carries the new role for the router gate.
      await _auth.refreshSession();
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
    await PushService.instance.clearToken();
    await _auth.signOut();
  }
}
