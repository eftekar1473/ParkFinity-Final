import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/notification_service.dart';
import '../../../../l10n/generated/app_localizations.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authStateChangesProvider).value?.session?.user;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(l10n.notLoggedIn)),
      );
    }

    final notificationsAsync = ref.watch(notificationsProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              ref.read(notificationServiceProvider).markAllAsRead(user.id);
            },
            child: Text(l10n.markAllAsRead, style: const TextStyle(color: Colors.deepPurple)),
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(child: Text(l10n.noNotificationsYet));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final isRead = notif['is_read'] == true;
              final createdAt = DateTime.parse(notif['created_at']);
              
              return InkWell(
                onTap: () {
                  if (!isRead) {
                    ref.read(notificationServiceProvider).markAsRead(notif['id']);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isRead ? Colors.grey.shade200 : Colors.deepPurple.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        notif['type'] == 'booking' ? Icons.directions_car : Icons.notifications,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif['title'] ?? l10n.notification,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif['message'] ?? '',
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat.yMMMd().add_jm().format(createdAt.toLocal()),
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('${l10n.error}: $error')),
      ),
    );
  }
}
