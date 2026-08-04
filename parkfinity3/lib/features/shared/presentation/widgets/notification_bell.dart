import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/notification_service.dart';

/// App-bar bell with a live unread count. Shared by every screen that shows a
/// notification entry point, so the badge can't drift between them.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value?.session?.user;
    if (user == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final unread =
        ref.watch(unreadNotificationCountProvider(user.id)).value ?? 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined,
              color: theme.colorScheme.onSurface),
          onPressed: () => context.push('/notifications'),
        ),
        if (unread > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                // Three digits of unread is already a wall; cap the label.
                unread > 99 ? '99+' : '$unread',
                style: TextStyle(
                  color: theme.colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
