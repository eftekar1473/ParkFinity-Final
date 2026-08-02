import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(Supabase.instance.client);
});

// Stream of unread notification count
final unreadNotificationCountProvider = StreamProvider.family<int, String>((ref, userId) {
  final service = ref.watch(notificationServiceProvider);
  return service.getUnreadCountStream(userId);
});

// Stream of all notifications for a user
final notificationsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  final service = ref.watch(notificationServiceProvider);
  return service.getNotificationsStream(userId);
});

class NotificationService {
  final SupabaseClient _client;

  NotificationService(this._client);

  Stream<int> getUnreadCountStream(String userId) {
    // .stream() allows only one .eq(); filter is_read in the mapper.
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((events) =>
            events.where((e) => e['is_read'] == false).length);
  }

  Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((events) => events.cast<Map<String, dynamic>>());
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // Helper to create a notification (usually done by backend, but we can do it here for now)
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'system',
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
    });
  }
}
