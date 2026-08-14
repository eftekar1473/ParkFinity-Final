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

/// Deep link Supabase redirects back to after the user clicks an email link
/// (confirmation or password recovery). Registered as an intent-filter in
/// AndroidManifest.xml; must match the redirect URLs allow-list in the
/// Supabase dashboard (Authentication → URL Configuration).
const String kAuthRedirect = 'io.supabase.parkfinity://login-callback/';

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
      // Clicking the confirmation link returns the user to the app, not a
      // browser dead-end.
      emailRedirectTo: kAuthRedirect,
      // handle_new_user() reads these to build the profiles row.
      data: {
        'full_name': fullName,
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phone_number': phoneNumber.trim(),
      },
    );
    // With email confirmation ON, signUp returns no session until the user
    // clicks the link, so there is no auth to attach a push token to yet.
    // Registering the token happens on the first real login instead.
    if (res.session != null) {
      await PushService.instance.registerToken();
    }
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

    final GoogleSignInAccount? googleUser;
    try {
      googleUser = await googleSignIn.signIn();
    } catch (e) {
      // PlatformException(sign_in_failed, ..., 10, ...) means SHA-1 mismatch.
      final msg = e.toString();
      if (msg.contains('10:') || msg.contains('sign_in_failed')) {
        throw const AuthException(
            'Google Sign-In failed. Please try again later or use email login.');
      }
      rethrow;
    }
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

  /// Sends a password-recovery email. The link deep-links back into the app,
  /// where onAuthStateChange fires a `passwordRecovery` event and the router
  /// sends the user to the reset screen.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.resetPasswordForEmail(email, redirectTo: kAuthRedirect);
  }

  /// Sets a new password for the recovery session established by the deep link.
  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() async {
    await PushService.instance.clearToken();
    await _auth.signOut();
  }
}
