import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(Supabase.instance.client);
});

class StorageRepository {
  final SupabaseClient _client;

  StorageRepository(this._client);

  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.webm':
        return 'video/webm';
      case '.3gp':
      case '.3gpp':
        return 'video/3gpp';
      case '.mkv':
        return 'video/x-matroska';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  /// Uploads a file (photo, video, document) using buffered binary data with
  /// explicit MIME type, upsert support, and automated retries for flaky mobile
  /// networks.
  Future<String> uploadImage(File file, String bucket, String folderPath) async {
    final rawExt = file.path.contains('.') ? file.path.split('.').last.toLowerCase() : '';
    final ext = rawExt.isNotEmpty ? '.$rawExt' : '.bin';
    final randomId = math.Random().nextInt(999999);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$randomId$ext';
    final cleanFolder = folderPath.replaceAll(RegExp(r'^[/\\]+|[/\\]+$'), '');
    final fullPath = '$cleanFolder/$fileName';

    final bytes = await file.readAsBytes();
    final mimeType = _getMimeType(ext);

    int attempt = 0;
    while (true) {
      attempt++;
      try {
        await _client.storage.from(bucket).uploadBinary(
          fullPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: mimeType,
          ),
        );
        break;
      } catch (e) {
        if (attempt >= 3) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    return _client.storage.from(bucket).getPublicUrl(fullPath);
  }

  Future<void> deleteImage(String path, String bucket) async {
    await _client.storage.from(bucket).remove([path]);
  }
}
