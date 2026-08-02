import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final currencyFormatter = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(l10n.myBookings, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
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
            final activeBookings = bookings.where((b) => b.status == 'Pending' && b.endTime.isAfter(now)).toList();
            final pastBookings = bookings.where((b) => !(b.status == 'Pending' && b.endTime.isAfter(now))).toList();

            return TabBarView(
              children: [
                _buildList(context, ref, activeBookings, currencyFormatter, reviewed),
                _buildList(context, ref, pastBookings, currencyFormatter, reviewed),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref,
      List<BookingModel> bookings, NumberFormat currencyFormatter,
      Set<String> reviewed) {
    final l10n = AppLocalizations.of(context);
    if (bookings.isEmpty) {
      return Center(child: Text(l10n.noBookings, style: const TextStyle(color: Colors.grey)));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final isUpcoming = booking.status == 'Pending' && booking.endTime.isAfter(DateTime.now());
        final isActive = booking.status == 'Pending' && booking.startTime.isBefore(DateTime.now()) && booking.endTime.isAfter(DateTime.now());
        
        String statusLabel = booking.status;
        Color statusColor = Colors.grey;
        
        if (isActive) {
          statusLabel = l10n.statusActive;
          statusColor = Colors.green;
        } else if (isUpcoming) {
          statusLabel = l10n.statusUpcoming;
          statusColor = Colors.orange;
        } else if (booking.status == 'Completed') {
          statusLabel = l10n.statusCompleted;
          statusColor = Colors.blue;
        } else if (booking.status == 'Cancelled') {
          statusLabel = l10n.statusCancelled;
          statusColor = Colors.red;
        }

        final dateStr = '${DateFormat('dd MMM yyyy').format(booking.startTime)}, ${DateFormat('HH:mm').format(booking.startTime)} - ${DateFormat('HH:mm').format(booking.endTime)}';

        final canReview = booking.status == 'Completed' &&
            booking.id != null &&
            !reviewed.contains(booking.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildBookingCard(
            title: booking.listing?.title ?? l10n.parkingSpot,
            address: booking.listing?.address ?? l10n.unknownAddress,
            date: dateStr,
            amount: currencyFormatter.format(booking.totalAmount),
            status: statusLabel,
            statusColor: statusColor,
            canReview: canReview,
            reviewLabel: l10n.rateThisSpot,
            onReview: canReview
                ? () async {
                    final ok = await ReviewSheet.show(
                      context,
                      bookingId: booking.id!,
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
    );
  }

  Widget _buildBookingCard({
    required String title,
    required String address,
    required String date,
    required String amount,
    required String status,
    required Color statusColor,
    bool canReview = false,
    String reviewLabel = '',
    VoidCallback? onReview,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text(address, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
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
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.deepPurple[400]),
                  const SizedBox(width: 8),
                  Text(date, style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)),
            ],
          ),
          if (canReview) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.star_border, size: 18),
                label: Text(reviewLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
