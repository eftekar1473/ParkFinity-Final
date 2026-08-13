import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/kyc_repository.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});

class AuthController extends AsyncNotifier<void> {
  late final AuthRepository _authRepository;

  @override
  FutureOr<void> build() {
    _authRepository = ref.watch(authRepositoryProvider);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.signInWithEmailAndPassword(email, password));
  }

  /// Returns true when a confirmation email was sent (no session yet), false
  /// when the user is signed in immediately (email confirmation disabled).
  Future<bool> register(String email, String password, String fullName,
      {String? phoneNumber}) async {
    state = const AsyncLoading();
    final res = await AsyncValue.guard(() =>
        _authRepository.signUpWithEmailAndPassword(email, password, fullName,
            phoneNumber: phoneNumber));
    state = res.whenData((_) {});
    return res.value?.session == null && !res.hasError;
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.signInWithGoogle());
  }

  /// Returns true when the recovery email was sent without error.
  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    final res = await AsyncValue.guard(
        () => _authRepository.sendPasswordResetEmail(email));
    state = res;
    return !res.hasError;
  }

  /// Returns true when the password was updated for the recovery session.
  Future<bool> updatePassword(String newPassword) async {
    state = const AsyncLoading();
    final res = await AsyncValue.guard(
        () => _authRepository.updatePassword(newPassword));
    state = res;
    return !res.hasError;
  }

  Future<void> updateRole(String role) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.updateRole(role));
  }

  /// Submits KYC docs, then refreshes so the JWT carries kyc_status=verified.
  Future<void> submitKyc({
    required File nidFront,
    required File nidBack,
    File? licenseFile,
    List<File> propertyDocs = const [],
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(kycRepositoryProvider).submitKyc(
          nidFront: nidFront,
          nidBack: nidBack,
          licenseFile: licenseFile,
          propertyDocs: propertyDocs,
        ));
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
  }
}
