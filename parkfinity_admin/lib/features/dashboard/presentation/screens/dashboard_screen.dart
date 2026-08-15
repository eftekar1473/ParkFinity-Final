import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Stream metrics via the admin_overview() RPC (admin-guarded, server-side). Polls every 5s.
final dashboardMetricsProvider = StreamProvider<Map<String, dynamic>>((ref) async* {
  final supabase = Supabase.instance.client;
  final res = await supabase.rpc('admin_overview');
  yield Map<String, dynamic>.from(res as Map);

  await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
    final res = await supabase.rpc('admin_overview');
    yield Map<String, dynamic>.from(res as Map);
  }
});

String _money(dynamic v) => '৳${(v as num?)?.toStringAsFixed(2) ?? '0.00'}';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardMetricsProvider),
          ),
        ],
      ),
      body: metricsAsync.when(
        data: (m) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Money', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(spacing: 20, runSpacing: 20, children: [
                  _MetricCard(title: 'Platform Revenue', value: _money(m['platform_revenue']), icon: Icons.monetization_on, color: Colors.green),
                  _MetricCard(title: 'Gross Volume', value: _money(m['gross_volume']), icon: Icons.show_chart, color: Colors.teal),
                  _MetricCard(title: 'Owner Payouts', value: _money(m['owner_payouts']), icon: Icons.payments, color: Colors.indigo),
                  _MetricCard(title: 'Refunded', value: _money(m['refunded_total']), icon: Icons.undo, color: Colors.orange),
                ]),
                const SizedBox(height: 32),
                Text('Users', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(spacing: 20, runSpacing: 20, children: [
                  _MetricCard(title: 'Total Users', value: '${m['total_users']}', icon: Icons.people),
                  _MetricCard(title: 'Riders', value: '${m['total_riders']}', icon: Icons.directions_car),
                  _MetricCard(title: 'Owners', value: '${m['total_owners']}', icon: Icons.store),
                  _MetricCard(title: 'Suspended', value: '${m['suspended_users']}', icon: Icons.block, color: Colors.red),
                  _MetricCard(title: 'Pending KYC', value: '${m['pending_kyc']}', icon: Icons.badge, color: Colors.amber),
                ]),
                const SizedBox(height: 32),
                Text('Activity', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(spacing: 20, runSpacing: 20, children: [
                  _MetricCard(title: 'Total Listings', value: '${m['total_listings']}', icon: Icons.local_parking),
                  _MetricCard(title: 'Active Listings', value: '${m['active_listings']}', icon: Icons.check_circle),
                  _MetricCard(title: 'Total Bookings', value: '${m['total_bookings']}', icon: Icons.book_online),
                  _MetricCard(title: 'Active Bookings', value: '${m['active_bookings']}', icon: Icons.timelapse, color: Colors.blue),
                  _MetricCard(title: 'Overstays', value: '${m['overstays']}', icon: Icons.warning, color: Colors.deepOrange),
                  _MetricCard(title: 'Pending Payouts', value: '${m['pending_withdrawals']}', icon: Icons.account_balance_wallet, color: Colors.purple),
                ]),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const _MetricCard({required this.title, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: color ?? Theme.of(context).primaryColor),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
