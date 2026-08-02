import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// All transactions, admin sees all (phase9 policy tx_admin_read). Embed user.
final transactionsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final rows = await supabase
      .from('transactions')
      .select('*, user:profiles!transactions_user_id_fkey(full_name, email)')
      .order('created_at', ascending: false)
      .limit(500);
  return List<Map<String, dynamic>>.from(rows);
});

final _txTypeFilterProvider = StateProvider<String>((ref) => 'All');

const _txTypes = ['All', 'deposit', 'booking_deduction', 'earning', 'withdrawal', 'refund', 'overstay_charge', 'commission'];

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsListProvider);
    final filter = ref.watch(_txTypeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Monitoring'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(transactionsListProvider)),
        ],
      ),
      body: txAsync.when(
        data: (all) {
          final rows = filter == 'All' ? all : all.where((t) => t['type'] == filter).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Text('Type: '),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: filter,
                    items: _txTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => ref.read(_txTypeFilterProvider.notifier).state = v!,
                  ),
                  const Spacer(),
                  Text('${rows.length} transaction(s)'),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('User')),
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Reference')),
                      DataColumn(label: Text('Date')),
                    ],
                    rows: rows.map(_row).toList(),
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

  DataRow _row(Map<String, dynamic> t) {
    final user = (t['user'] as Map?) ?? {};
    final type = (t['type'] ?? '').toString();
    return DataRow(cells: [
      DataCell(Text(user['full_name'] ?? user['email'] ?? 'N/A')),
      DataCell(Text('৳${t['amount'] ?? '0.0'}',
          style: TextStyle(
              color: type == 'refund' || type == 'deposit' ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600))),
      DataCell(Chip(label: Text(type, style: const TextStyle(fontSize: 12)))),
      DataCell(Text(t['status'] ?? '-')),
      DataCell(Text(t['reference_id'] ?? '-', style: const TextStyle(fontSize: 12))),
      DataCell(Text(_fmt(t['created_at']))),
    ]);
  }

  static String _fmt(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    return s.length >= 16 ? s.substring(0, 16).replaceFirst('T', ' ') : s;
  }
}
