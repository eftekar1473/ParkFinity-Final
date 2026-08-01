import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final dashboardMetricsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  
  final users = await supabase.from('profiles').select('id').count(CountOption.exact);
  final listings = await supabase.from('listings').select('id').count(CountOption.exact);
  final bookings = await supabase.from('bookings').select('id').count(CountOption.exact);
  
  // Calculate total platform commission
  final bookingsData = await supabase.from('bookings').select('commission_amount').eq('status', 'Completed');
  double totalRevenue = 0;
  for (var b in bookingsData) {
    totalRevenue += (b['commission_amount'] as num).toDouble();
  }

  return {
    'total_users': users.count,
    'total_listings': listings.count,
    'total_bookings': bookings.count,
    'total_revenue': totalRevenue,
  };
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: metricsAsync.when(
        data: (metrics) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overview', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _MetricCard(title: 'Total Users', value: metrics['total_users'].toString(), icon: Icons.people),
                    _MetricCard(title: 'Total Listings', value: metrics['total_listings'].toString(), icon: Icons.local_parking),
                    _MetricCard(title: 'Total Bookings', value: metrics['total_bookings'].toString(), icon: Icons.book_online),
                    _MetricCard(title: 'Platform Revenue', value: '৳${metrics['total_revenue']}', icon: Icons.monetization_on, color: Colors.green),
                  ],
                ),
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
        width: 250,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: color ?? Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
