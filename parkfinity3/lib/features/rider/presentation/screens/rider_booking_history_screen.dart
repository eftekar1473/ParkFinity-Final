import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/rider_bookings_provider.dart';
import '../../../../shared/data/models/booking_model.dart';

class RiderBookingHistoryScreen extends ConsumerWidget {
  const RiderBookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(riderBookingsProvider);
    final currencyFormatter = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('My Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
            tabs: [
              Tab(text: 'Upcoming & Active'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: bookingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (bookings) {
            final now = DateTime.now();
            final activeBookings = bookings.where((b) => b.status == 'Pending' && b.endTime.isAfter(now)).toList();
            final pastBookings = bookings.where((b) => !(b.status == 'Pending' && b.endTime.isAfter(now))).toList();

            return TabBarView(
              children: [
                _buildList(activeBookings, currencyFormatter),
                _buildList(pastBookings, currencyFormatter),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<BookingModel> bookings, NumberFormat currencyFormatter) {
    if (bookings.isEmpty) {
      return const Center(child: Text('No bookings found.', style: TextStyle(color: Colors.grey)));
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
          statusLabel = 'Active';
          statusColor = Colors.green;
        } else if (isUpcoming) {
          statusLabel = 'Upcoming';
          statusColor = Colors.orange;
        } else if (booking.status == 'Completed') {
          statusColor = Colors.blue;
        } else if (booking.status == 'Cancelled') {
          statusColor = Colors.red;
        }

        final dateStr = '${DateFormat('dd MMM yyyy').format(booking.startTime)}, ${DateFormat('HH:mm').format(booking.startTime)} - ${DateFormat('HH:mm').format(booking.endTime)}';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildBookingCard(
            title: booking.listing?.title ?? 'Parking Spot',
            address: booking.listing?.address ?? 'Unknown Address',
            date: dateStr,
            amount: currencyFormatter.format(booking.totalAmount),
            status: statusLabel,
            statusColor: statusColor,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
                  color: statusColor.withOpacity(0.1),
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
        ],
      ),
    );
  }
}
