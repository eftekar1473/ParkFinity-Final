import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../controllers/rider_bookings_provider.dart';
import '../../../../shared/data/models/booking_model.dart';
import '../../../rider/data/repositories/reviews_repository.dart';
import '../../../shared/presentation/widgets/review_sheet.dart';
import '../../../../l10n/generated/app_localizations.dart';

class RiderBookingHistoryScreen extends ConsumerWidget {
  const RiderBookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookingsAsync = ref.watch(riderBookingsProvider);
    final reviewedAsync = ref.watch(reviewedBookingIdsProvider(false));
    final reviewed = reviewedAsync.value ?? const <String>{};
    final money = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.myBookings,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.upcomingActive),
              Tab(text: l10n.past),
            ],
          ),
        ),
        body: bookingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('${l10n.error}: $err')),
          data: (bookings) {
            final now = DateTime.now();
            // "Live" = anything not yet finished or cancelled. Status alone is
            // not enough: a Confirmed booking is still upcoming.
            const live = {'Pending', 'Confirmed', 'Active'};
            final current = bookings
                .where((b) => live.contains(b.status) && b.endTime.isAfter(now))
                .toList();
            final past = bookings
                .where((b) =>
                    !(live.contains(b.status) && b.endTime.isAfter(now)))
                .toList();

            return TabBarView(
              children: [
                _List(bookings: current, money: money, reviewed: reviewed),
                _List(bookings: past, money: money, reviewed: reviewed),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  final List<BookingModel> bookings;
  final NumberFormat money;
  final Set<String> reviewed;

  const _List({
    required this.bookings,
    required this.money,
    required this.reviewed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (bookings.isEmpty) {
      return Center(
        child: Text(l10n.noBookings,
            style: TextStyle(color: Theme.of(context).hintColor)),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(riderBookingsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final b = bookings[index];
          final canReview = b.status == 'Completed' &&
              b.id != null &&
              !reviewed.contains(b.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: BookingCard(
              booking: b,
              money: money,
              onTap: () => context.push('/booking', extra: b),
              onReview: canReview
                  ? () async {
                      final ok = await ReviewSheet.show(
                        context,
                        bookingId: b.id!,
                        asOwner: false,
                        targetLabel: l10n.thisParkingSpot,
                      );
                      if (ok == true) {
                        ref.invalidate(reviewedBookingIdsProvider(false));
                      }
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }
}

/// Tappable summary of one booking. Shared by the rider and owner lists.
class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final NumberFormat money;
  final VoidCallback onTap;
  final VoidCallback? onReview;

  /// Owners see their payout, riders see what they paid.
  final bool asOwner;

  const BookingCard({
    super.key,
    required this.booking,
    required this.money,
    required this.onTap,
    this.onReview,
    this.asOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();

    final (statusLabel, statusColor) = switch (booking.status) {
      'Cancelled' => (l10n.statusCancelled, theme.colorScheme.error),
      'Completed' => (l10n.statusCompleted, Colors.blue),
      'Active' => (l10n.statusActive, Colors.green),
      _ when booking.startTime.isBefore(now) && booking.endTime.isAfter(now) =>
        (l10n.statusActive, Colors.green),
      _ => (l10n.statusUpcoming, Colors.orange),
    };

    final dateStr =
        '${DateFormat('dd MMM yyyy').format(booking.startTime.toLocal())}, '
        '${DateFormat('HH:mm').format(booking.startTime.toLocal())} - '
        '${DateFormat('HH:mm').format(booking.endTime.toLocal())}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.listing?.title ?? l10n.parkingSpot,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 14, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              booking.listing?.address ?? l10n.unknownAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: theme.hintColor, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(dateStr,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
                Text(
                  money.format(asOwner
                      ? booking.ownerEarnings
                      : booking.totalAmount),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.primary),
                ),
              ],
            ),
            if (onReview != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.star_border, size: 18),
                  label: Text(l10n.rateThisSpot),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
