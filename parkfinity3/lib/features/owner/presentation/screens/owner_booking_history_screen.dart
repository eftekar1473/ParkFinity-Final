import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../controllers/owner_bookings_provider.dart';
import '../../../../shared/data/models/booking_model.dart';
import '../../../rider/data/repositories/reviews_repository.dart';
import '../../../rider/presentation/screens/rider_booking_history_screen.dart'
    show BookingCard;
import '../../../shared/data/my_profile_repository.dart';
import '../../../shared/presentation/widgets/review_sheet.dart';
import '../../../../l10n/generated/app_localizations.dart';

class OwnerBookingHistoryScreen extends ConsumerWidget {
  const OwnerBookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookingsAsync = ref.watch(ownerBookingsProvider);
    final reviewed =
        ref.watch(reviewedBookingIdsProvider(true)).value ?? const <String>{};
    final money = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.bookings,
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
      onRefresh: () async => ref.invalidate(ownerBookingsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final b = bookings[index];
          final canReview =
              b.status == 'Completed' && b.id != null && !reviewed.contains(b.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RiderLine(riderId: b.riderId),
                const SizedBox(height: 6),
                BookingCard(
                  booking: b,
                  money: money,
                  asOwner: true,
                  onTap: () =>
                      context.push('/booking?owner=1', extra: b),
                  onReview: canReview
                      ? () async {
                          final ok = await ReviewSheet.show(
                            context,
                            bookingId: b.id!,
                            asOwner: true,
                            targetLabel: l10n.thisRider,
                          );
                          if (ok == true) {
                            ref.invalidate(reviewedBookingIdsProvider(true));
                          }
                        }
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Who booked. Falls back to a shortened id while the profile loads or if the
/// rider has no name set.
class _RiderLine extends ConsumerWidget {
  final String riderId;
  const _RiderLine({required this.riderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = ref.watch(publicProfileProvider(riderId)).value?.fullName;

    return Row(
      children: [
        Icon(Icons.person_outline, size: 16, color: theme.hintColor),
        const SizedBox(width: 6),
        Text(
          (name != null && name.trim().isNotEmpty)
              ? name
              : l10n.riderLabel(riderId.substring(0, 5)),
          style: TextStyle(
              color: theme.hintColor, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}
