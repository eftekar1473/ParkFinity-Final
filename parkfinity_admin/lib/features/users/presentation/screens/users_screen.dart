import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/presentation/widgets/kyc_docs_dialog.dart';

final usersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final rows = await supabase.from('profiles').select().order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
});

final userSearchProvider = StateProvider<String>((ref) => '');

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);
    final query = ref.watch(userSearchProvider).toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(usersListProvider),
          ),
        ],
      ),
      body: usersAsync.when(
        data: (all) {
          final users = query.isEmpty
              ? all
              : all.where((u) {
                  final n = (u['full_name'] ?? '').toString().toLowerCase();
                  final e = (u['email'] ?? '').toString().toLowerCase();
                  return n.contains(query) || e.contains(query);
                }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => ref.read(userSearchProvider.notifier).state = v,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Wallet')),
                        DataColumn(label: Text('KYC')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: users.map((user) => _row(context, ref, user)).toList(),
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

  DataRow _row(BuildContext context, WidgetRef ref, Map<String, dynamic> user) {
    final suspended = user['is_suspended'] == true;
    final kyc = (user['kyc_status'] ?? 'none').toString();
    return DataRow(cells: [
      DataCell(Text(user['full_name'] ?? 'N/A')),
      DataCell(Text(user['email'] ?? 'N/A')),
      DataCell(Text(user['role'] ?? 'N/A')),
      DataCell(Text('৳${user['wallet_balance'] ?? '0.0'}')),
      DataCell(_chip(kyc, kyc == 'verified' ? Colors.green : (kyc == 'pending' ? Colors.orange : Colors.grey))),
      DataCell(_chip(suspended ? 'Suspended' : 'Active', suspended ? Colors.red : Colors.green)),
      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'View KYC docs',
          icon: const Icon(Icons.badge_outlined),
          onPressed: () => KycDocsDialog.show(context, user),
        ),
        TextButton(
          onPressed: () async {
            try {
              await Supabase.instance.client.rpc('admin_set_suspended',
                  params: {'p_user': user['id'], 'p_suspended': !suspended});
              ref.invalidate(usersListProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red));
              }
            }
          },
          style: TextButton.styleFrom(foregroundColor: suspended ? Colors.green : Colors.red),
          child: Text(suspended ? 'Activate' : 'Suspend'),
        ),
      ])),
    ]);
  }

  Widget _chip(String label, Color color) => Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: color.withValues(alpha: 0.15),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}
