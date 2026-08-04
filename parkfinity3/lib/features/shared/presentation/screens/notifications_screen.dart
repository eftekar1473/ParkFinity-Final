import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/data/repositories/bookings_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/notification_service.dart';

/// Icon + tint per notification `type`. Types are produced by the backend:
/// booking, reminder, overstay, payment, withdrawal, kyc, account, review.
({IconData icon, Color color}) _visual(String? type, ThemeData theme) {
  switch (type) {
    case 'booking':
      return (icon: Icons.directions_car, color: theme.colorScheme.primary);
    case 'reminder':
      return (icon: Icons.alarm, color: Colors.orange);
    case 'overstay':
      return (icon: Icons.running_with_errors, color: theme.colorScheme.error);
    case 'payment':
      return (icon: Icons.payments_outlined, color: Colors.green);
    case 'withdrawal':
      return (icon: Icons.account_balance_outlined, color: Colors.green);
    case 'kyc':
      return (icon: Icons.verified_user_outlined, color: theme.colorScheme.primary);
    case 'account':
      return (icon: Icons.person_off_outlined, color: theme.colorScheme.error);
    case 'review':
      return (icon: Icons.star_outline, color: Colors.amber);
    default:
      return (icon: Icons.notifications, color: theme.colorScheme.primary);
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  /// Opens whatever the notification points at. Booking-scoped types carry a
  /// `booking_id`; the rest land on the screen where the change is visible.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> notif,
  ) async {
    final l10n = AppLocalizations.of(context);
    final data = (notif['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final type = notif['type'] as String?;
    final bookingId = data['booking_id'] as String?;
    final role = (ref
                .read(authStateChangesProvider)
                .value
                ?.session
                ?.user
                .userMetadata?['role'] as String?)
            ?.toLowerCase() ??
        'rider';
    final asOwner = role == 'owner';

    if (bookingId != null) {
      final booking =
          await ref.read(bookingsRepositoryProvider).getBooking(bookingId);
      if (!context.mounted) return;
      if (booking == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.noResults)));
        return;
      }
      context.push('/booking?owner=${asOwner ? 1 : 0}', extra: booking);
      return;
    }

    switch (type) {
      case 'payment':
      case 'withdrawal':
        context.push(asOwner ? '/owner/wallet' : '/rider/wallet');
      case 'kyc':
        context.push(asOwner ? '/owner/profile' : '/rider/profile');
      case 'review':
        context.push(asOwner ? '/owner/bookings' : '/rider/bookings');
      default:
        break; // Nothing more specific to show.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authStateChangesProvider).value?.session?.user;

    if (user == null) {
      return Scaffold(body: Center(child: Text(l10n.notLoggedIn)));
    }

    final notificationsAsync = ref.watch(notificationsProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationServiceProvider).markAllAsRead(user.id),
            child: Text(l10n.markAllAsRead,
                style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.surface,
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(child: Text(l10n.noNotificationsYet));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final isRead = notif['is_read'] == true;
              final createdAt = DateTime.parse(notif['created_at']);
              final v = _visual(notif['type'] as String?, theme);

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (!isRead) {
                    ref
                        .read(notificationServiceProvider)
                        .markAsRead(notif['id']);
                  }
                  _open(context, ref, notif);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRead
                        ? theme.colorScheme.surfaceContainerLow
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isRead
                            ? theme.dividerColor
                            : theme.colorScheme.primary),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(v.icon, color: v.color),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif['title'] ?? l10n.notification,
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif['message'] ?? '',
                              style: TextStyle(color: theme.hintColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat.yMMMd()
                                  .add_jm()
                                  .format(createdAt.toLocal()),
                              style: TextStyle(
                                  color: theme.hintColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
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
        error: (error, _) => Center(child: Text('${l10n.error}: $error')),
      ),
    );
  }
}
