import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(Supabase.instance.client);
});

// Stream of unread notification count
final unreadNotificationCountProvider = StreamProvider.family.autoDispose<int, String>((ref, userId) async* {
  final service = ref.watch(notificationServiceProvider);
  yield await service.getUnreadCount(userId);
  await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
    yield await service.getUnreadCount(userId);
  }
});

// Stream of all notifications for a user
final notificationsProvider = StreamProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, userId) async* {
  final service = ref.watch(notificationServiceProvider);
  yield await service.getNotifications(userId);
  await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
    yield await service.getNotifications(userId);
  }
});

class NotificationService {
  final SupabaseClient _client;

  NotificationService(this._client);

  Future<int> getUnreadCount(String userId) async {
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (response as List).length;
  }

  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>().toList();
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
