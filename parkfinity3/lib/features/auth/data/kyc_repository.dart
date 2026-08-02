import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/repositories/storage_repository.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  return KycRepository(
    Supabase.instance.client,
    ref.watch(storageRepositoryProvider),
  );
});

/// Persists KYC documents to Supabase Storage (`documents` bucket) and mirrors
/// the resulting URLs + status onto the profile. A DB trigger propagates
/// kyc_status into the auth JWT metadata so the router gate sees it.
class KycRepository {
  final SupabaseClient _client;
  final StorageRepository _storage;

  KycRepository(this._client, this._storage);

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Not logged in');
    return id;
  }

  Future<String> _upload(File file, String label) {
    // Foldered per user so admin can review all of a user's docs together.
    return _storage.uploadImage(file, 'documents', '$_uid/kyc/$label');
  }

  /// Uploads NID front + back (+ role-specific doc) and marks the profile
  /// verified. [licenseFile] required for riders; [propertyDocs] for owners.
  Future<void> submitKyc({
    required File nidFront,
    required File nidBack,
    File? licenseFile,
    List<File> propertyDocs = const [],
  }) async {
    final frontUrl = await _upload(nidFront, 'nid_front');
    final backUrl = await _upload(nidBack, 'nid_back');

    final update = <String, dynamic>{
      'nid_front_url': frontUrl,
      'nid_back_url': backUrl,
      'kyc_status': 'verified',
    };

    if (licenseFile != null) {
      update['license_url'] = await _upload(licenseFile, 'license');
    }

    if (propertyDocs.isNotEmpty) {
      final urls = <String>[];
      for (var i = 0; i < propertyDocs.length; i++) {
        urls.add(await _upload(propertyDocs[i], 'property_$i'));
      }
      update['property_docs'] = urls;
    }

    // Update profile (trigger syncs kyc_status -> auth metadata).
    await _client.from('profiles').update(update).eq('id', _uid);

    // Refresh the local session so the JWT carries the new kyc_status
    // immediately, letting the router gate release the user without a re-login.
    await _client.auth.refreshSession();
  }
}
