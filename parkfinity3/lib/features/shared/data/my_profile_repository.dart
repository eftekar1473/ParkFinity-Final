import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/repositories/storage_repository.dart';

/// The signed-in user's own profile, as returned by the `my_profile()` RPC.
class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final String role;
  final String kycStatus;
  final double walletBalance;
  final bool hasPaymentDue;
  final double avgRating;
  final int reviewCount;
  final String? nidFrontUrl;
  final String? nidBackUrl;
  final String? licenseUrl;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    this.role = 'Rider',
    this.kycStatus = 'none',
    this.walletBalance = 0,
    this.hasPaymentDue = false,
    this.avgRating = 0,
    this.reviewCount = 0,
    this.nidFrontUrl,
    this.nidBackUrl,
    this.licenseUrl,
    this.createdAt,
  });

  bool get isOwner => role.toLowerCase() == 'owner';
  bool get isVerified => kycStatus == 'verified';

  /// Falls back to the email local-part so the header never shows a blank name.
  String get displayName =>
      fullName.trim().isNotEmpty ? fullName.trim() : email.split('@').first;

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        email: (j['email'] as String?) ?? '',
        fullName: (j['full_name'] as String?) ?? '',
        phoneNumber: j['phone_number'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        role: (j['role'] as String?) ?? 'Rider',
        kycStatus: (j['kyc_status'] as String?) ?? 'none',
        walletBalance: (j['wallet_balance'] as num?)?.toDouble() ?? 0,
        hasPaymentDue: (j['has_payment_due'] as bool?) ?? false,
        avgRating: (j['avg_rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
        nidFrontUrl: j['nid_front_url'] as String?,
        nidBackUrl: j['nid_back_url'] as String?,
        licenseUrl: j['license_url'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString())
            : null,
      );
}

final myProfileRepositoryProvider = Provider<MyProfileRepository>((ref) {
  return MyProfileRepository(
    Supabase.instance.client,
    ref.watch(storageRepositoryProvider),
  );
});

class MyProfileRepository {
  final SupabaseClient _client;
  final StorageRepository _storage;

  MyProfileRepository(this._client, this._storage);

  Future<UserProfile?> me() async {
    if (_client.auth.currentUser == null) return null;
    final res = await _client.rpc('my_profile');
    if (res == null) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Server validates the phone format and ignores anything left null.
  Future<UserProfile> update({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final res = await _client.rpc('update_my_profile', params: {
      'p_full_name': fullName,
      'p_phone': phone,
      'p_avatar': avatarUrl,
    });
    final map = Map<String, dynamic>.from(res as Map);
    if (map['ok'] != true) {
      throw Exception(map['msg'] ?? 'Could not update profile');
    }
    return UserProfile.fromJson(
        Map<String, dynamic>.from(map['profile'] as Map));
  }

  /// Uploads to the public `avatars` bucket under the user's own folder.
  Future<String> uploadAvatar(File file) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not logged in');
    return _storage.uploadImage(file, 'avatars', uid);
  }
}

/// Single source of truth for "who am I" across every screen.
final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  // Re-resolve whenever auth changes (login, logout, role switch).
  ref.watch(authChangeTickProvider);
  return ref.watch(myProfileRepositoryProvider).me();
});

/// Bumps whenever the Supabase auth state changes so the profile refetches.
final authChangeTickProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Public profile of any other user (host card, booking counterpart).
class PublicProfile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? phoneNumber;
  final String? role;

  const PublicProfile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.phoneNumber,
    this.role,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
        id: j['id'] as String,
        fullName: j['full_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        phoneNumber: j['phone_number'] as String?,
        role: j['role'] as String?,
      );
}

final publicProfileProvider =
    FutureProvider.family<PublicProfile?, String>((ref, userId) async {
  final rows = await Supabase.instance.client
      .from('public_profiles')
      .select('id, full_name, avatar_url, phone_number, role')
      .eq('id', userId)
      .limit(1);
  if ((rows as List).isEmpty) return null;
  return PublicProfile.fromJson(Map<String, dynamic>.from(rows.first as Map));
});
