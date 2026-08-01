import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final listingsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase.from('listings').select().order('created_at', ascending: false);
});

class ListingsScreen extends ConsumerWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(listingsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listings Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(listingsListProvider),
          ),
        ],
      ),
      body: listingsAsync.when(
        data: (listings) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: double.infinity),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Title')),
                    DataColumn(label: Text('Address')),
                    DataColumn(label: Text('Hourly Rate')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: listings.map((listing) {
                    final isActive = listing['is_active'] == true;
                    return DataRow(
                      cells: [
                        DataCell(Text(listing['title'] ?? 'N/A')),
                        DataCell(
                          SizedBox(
                            width: 200,
                            child: Text(
                              listing['address'] ?? 'N/A',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text('৳${listing['hourly_rate'] ?? '0.0'}')),
                        DataCell(
                          Chip(
                            label: Text(isActive ? 'Active' : 'Inactive'),
                            backgroundColor: isActive ? Colors.green.shade100 : Colors.red.shade100,
                          ),
                        ),
                        DataCell(
                          TextButton(
                            onPressed: () async {
                              final supabase = Supabase.instance.client;
                              await supabase.from('listings').update({'is_active': !isActive}).eq('id', listing['id']);
                              ref.invalidate(listingsListProvider);
                            },
                            child: Text(isActive ? 'Suspend' : 'Activate'),
                          ),
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
