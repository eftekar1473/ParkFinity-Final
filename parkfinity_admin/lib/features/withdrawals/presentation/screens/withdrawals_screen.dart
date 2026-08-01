import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final withdrawalsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  // Join with profiles to get owner name
  return await supabase.from('withdrawals').select('*, profiles(full_name, email)').order('created_at', ascending: false);
});

class WithdrawalsScreen extends ConsumerWidget {
  const WithdrawalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final withdrawalsAsync = ref.watch(withdrawalsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(withdrawalsListProvider),
          ),
        ],
      ),
      body: withdrawalsAsync.when(
        data: (withdrawals) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: double.infinity),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Owner')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Bank Details')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: withdrawals.map((withdrawal) {
                    final status = withdrawal['status'] ?? 'Pending';
                    final profile = withdrawal['profiles'] ?? {};
                    return DataRow(
                      cells: [
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(profile['full_name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(profile['email'] ?? 'N/A', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        DataCell(Text('৳${withdrawal['amount'] ?? '0.0'}')),
                        DataCell(
                          SizedBox(
                            width: 200,
                            child: SelectableText(
                              withdrawal['bank_account_details'] ?? 'N/A',
                            ),
                          ),
                        ),
                        DataCell(
                          Chip(
                            label: Text(status),
                            backgroundColor: status == 'Pending' 
                              ? Colors.orange.shade100 
                              : (status == 'Completed' ? Colors.green.shade100 : Colors.red.shade100),
                          ),
                        ),
                        DataCell(
                          status == 'Pending' ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  final supabase = Supabase.instance.client;
                                  // In real app, we might call an RPC to properly handle balance deduct if it wasn't already
                                  await supabase.from('withdrawals').update({'status': 'Completed', 'processed_at': DateTime.now().toIso8601String()}).eq('id', withdrawal['id']);
                                  ref.invalidate(withdrawalsListProvider);
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.green),
                                child: const Text('Complete'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final supabase = Supabase.instance.client;
                                  await supabase.from('withdrawals').update({'status': 'Rejected', 'processed_at': DateTime.now().toIso8601String()}).eq('id', withdrawal['id']);
                                  ref.invalidate(withdrawalsListProvider);
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Reject'),
                              ),
                            ],
                          ) : const Text('-'),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
