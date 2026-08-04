import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../controllers/owner_bookings_provider.dart';
import '../../../shared/presentation/widgets/notification_bell.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookingsAsync = ref.watch(ownerBookingsProvider);
    final currencyFormatter = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.dashboard, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        elevation: 0,
        actions: const [NotificationBell()],
      ),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${l10n.error}: $err')),
        data: (bookings) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          double todayEarnings = 0;
          int activeBookings = 0;

          for (final b in bookings) {
            // Active if status is pending and currently within time
            if (b.status == 'Pending' && b.startTime.isBefore(now) && b.endTime.isAfter(now)) {
              activeBookings++;
            }
            
            // Today's earnings if start time is today
            final bDate = DateTime(b.startTime.year, b.startTime.month, b.startTime.day);
            if (bDate.isAtSameMomentAs(today)) {
              todayEarnings += b.ownerEarnings;
            }
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(adaptivePadding(context)),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: adaptiveMaxWidth(context)),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Header
                Text(
                  l10n.welcomeBackOwner,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Statistics Grid
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: l10n.todaysEarnings,
                        value: currencyFormatter.format(todayEarnings),
                        icon: Icons.attach_money,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: l10n.activeParkings,
                        value: activeBookings.toString(),
                        icon: Icons.directions_car,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _StatCard(
                  title: l10n.totalBookingsEver,
                  value: bookings.length.toString(),
                  icon: Icons.history,
                  color: Colors.orange,
                  isFullWidth: true,
                ),

                const SizedBox(height: 32),

                // Quick Actions
                Text(
                  l10n.quickActions,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    context.push('/add_listing');
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addNewParkingSpot),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/withdraw'),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(l10n.withdrawEarnings),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isFullWidth;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              if (isFullWidth)
                Text(
                  value,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isFullWidth)
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
