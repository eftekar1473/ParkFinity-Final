import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/presentation/widgets/kyc_docs_dialog.dart';

// Users who have submitted any KYC evidence — pending first, then verified.
final kycQueueProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final rows = await supabase
      .from('profiles')
      .select()
      .order('kyc_status', ascending: true)
      .order('created_at', ascending: false);
  final list = List<Map<String, dynamic>>.from(rows);
  bool hasDocs(Map u) =>
      (u['nid_front_url'] ?? u['nid_back_url'] ?? u['license_url'] ?? u['nid_url']) != null ||
      ((u['property_docs'] as List?)?.isNotEmpty ?? false);
  // Keep users that either need review or carry evidence.
  return list.where((u) => u['kyc_status'] == 'pending' || hasDocs(u)).toList();
});

final _kycFilterProvider = StateProvider<String>((ref) => 'pending');

class KycScreen extends ConsumerWidget {
  const KycScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(kycQueueProvider);
    final filter = ref.watch(_kycFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Review'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(kycQueueProvider)),
        ],
      ),
      body: queueAsync.when(
        data: (all) {
          final users = filter == 'all' ? all : all.where((u) => u['kyc_status'] == filter).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Text('Filter: '),
                  const SizedBox(width: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'pending', label: Text('Pending')),
                      ButtonSegment(value: 'verified', label: Text('Verified')),
                      ButtonSegment(value: 'all', label: Text('All')),
                    ],
                    selected: {filter},
                    onSelectionChanged: (s) => ref.read(_kycFilterProvider.notifier).state = s.first,
                  ),
                ]),
              ),
              Expanded(
                child: users.isEmpty
                    ? const Center(child: Text('Nothing to review.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: users.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _KycTile(user: users[i]),
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
}

class _KycTile extends ConsumerWidget {
  final Map<String, dynamic> user;
  const _KycTile({required this.user});

  Future<void> _setKyc(BuildContext context, WidgetRef ref, String status) async {
    try {
      await Supabase.instance.client.rpc('admin_set_kyc', params: {'p_user': user['id'], 'p_status': status});
      ref.invalidate(kycQueueProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KYC set to $status')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kyc = (user['kyc_status'] ?? 'none').toString();
    final color = kyc == 'verified' ? Colors.green : (kyc == 'pending' ? Colors.orange : Colors.grey);
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(Icons.person, color: color)),
        title: Text(user['full_name'] ?? user['email'] ?? 'N/A'),
        subtitle: Text('${user['email'] ?? ''}  •  ${user['role'] ?? ''}  •  KYC: $kyc'),
        trailing: Wrap(spacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () => KycDocsDialog.show(context, user),
            icon: const Icon(Icons.image, size: 18),
            label: const Text('Docs'),
          ),
          FilledButton(
            onPressed: kyc == 'verified' ? null : () => _setKyc(context, ref, 'verified'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Verify'),
          ),
          OutlinedButton(
            onPressed: () => _setKyc(context, ref, 'none'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ]),
      ),
    );
  }
}
