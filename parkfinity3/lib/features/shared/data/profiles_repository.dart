import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public profile of a listing's owner (host card on details screen).
class HostProfile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final DateTime? joinedAt;

  HostProfile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.joinedAt,
  });

  factory HostProfile.fromJson(Map<String, dynamic> json) => HostProfile(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        joinedAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
}

final profilesRepositoryProvider = Provider<ProfilesRepository>((ref) {
  return ProfilesRepository(Supabase.instance.client);
});

class ProfilesRepository {
  final SupabaseClient _client;
  ProfilesRepository(this._client);

  Future<HostProfile?> getProfile(String userId) async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name, avatar_url, created_at')
        .eq('id', userId)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return HostProfile.fromJson(rows.first);
  }
}

/// Fetch one host profile by owner id (used by listing details host card).
final hostProfileProvider =
    FutureProvider.family<HostProfile?, String>((ref, ownerId) async {
  return ref.watch(profilesRepositoryProvider).getProfile(ownerId);
});
