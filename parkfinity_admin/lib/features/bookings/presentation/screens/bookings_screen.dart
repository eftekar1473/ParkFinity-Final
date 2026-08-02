import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// All bookings with rider + listing context. bookings RLS is open for admin
// (anon read) so a direct select with embeds works.
final bookingsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final rows = await supabase
      .from('bookings')
      .select('*, rider:profiles!bookings_rider_id_fkey(full_name, email), listing:listings(title, address)')
      .order('created_at', ascending: false)
      .limit(500);
  return List<Map<String, dynamic>>.from(rows);
});

final _statusFilterProvider = StateProvider<String>((ref) => 'All');

const _statuses = ['All', 'Pending', 'Confirmed', 'Active', 'Completed', 'Cancelled', 'Overstayed', 'Refunded'];

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(bookingsListProvider);
    final filter = ref.watch(_statusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Monitoring'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(bookingsListProvider)),
        ],
      ),
      body: bookingsAsync.when(
        data: (all) {
          final rows = filter == 'All' ? all : all.where((b) => b['status'] == filter).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Text('Status: '),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: filter,
                    items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => ref.read(_statusFilterProvider.notifier).state = v!,
                  ),
                  const Spacer(),
                  Text('${rows.length} booking(s)'),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Rider')),
                        DataColumn(label: Text('Listing')),
                        DataColumn(label: Text('Vehicle')),
                        DataColumn(label: Text('Start')),
                        DataColumn(label: Text('End')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Commission')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: rows.map(_row).toList(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  DataRow _row(Map<String, dynamic> b) {
    final rider = (b['rider'] as Map?) ?? {};
    final listing = (b['listing'] as Map?) ?? {};
    final status = (b['status'] ?? '').toString();
    return DataRow(cells: [
      DataCell(Text(rider['full_name'] ?? rider['email'] ?? 'N/A')),
      DataCell(SizedBox(width: 160, child: Text(listing['title'] ?? 'N/A', overflow: TextOverflow.ellipsis))),
      DataCell(Text(b['vehicle_type'] ?? '-')),
      DataCell(Text(_fmt(b['start_time']))),
      DataCell(Text(_fmt(b['end_time']))),
      DataCell(Text('৳${b['total_amount'] ?? 0}')),
      DataCell(Text('৳${b['commission_amount'] ?? 0}')),
      DataCell(Chip(
        label: Text(status, style: const TextStyle(fontSize: 12)),
        backgroundColor: _statusColor(status).withValues(alpha: 0.15),
        side: BorderSide(color: _statusColor(status).withValues(alpha: 0.4)),
      )),
    ]);
  }

  static String _fmt(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    return s.length >= 16 ? s.substring(0, 16).replaceFirst('T', ' ') : s;
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'Completed':
        return Colors.green;
      case 'Active':
      case 'Confirmed':
        return Colors.blue;
      case 'Pending':
        return Colors.orange;
      case 'Overstayed':
        return Colors.deepOrange;
      case 'Cancelled':
        return Colors.grey;
      case 'Refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
