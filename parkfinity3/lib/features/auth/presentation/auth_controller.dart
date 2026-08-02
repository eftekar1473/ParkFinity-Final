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

  Future<void> register(String email, String password, String fullName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.signUpWithEmailAndPassword(email, password, fullName));
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.signInWithGoogle());
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
