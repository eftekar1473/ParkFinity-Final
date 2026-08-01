import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(Supabase.instance.client);
});

class StorageRepository {
  final SupabaseClient _client;

  StorageRepository(this._client);

  Future<String> uploadImage(File file, String bucket, String folderPath) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final fullPath = '$folderPath/$fileName';
    
    await _client.storage.from(bucket).upload(fullPath, file);
    return _client.storage.from(bucket).getPublicUrl(fullPath);
  }

  Future<void> deleteImage(String path, String bucket) async {
    await _client.storage.from(bucket).remove([path]);
  }
}
