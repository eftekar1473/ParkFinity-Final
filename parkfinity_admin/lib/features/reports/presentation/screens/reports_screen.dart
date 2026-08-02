import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _rangeProvider = StateProvider<int>((ref) => 30);

// Revenue time series from admin_daily_revenue(days) RPC.
final dailyRevenueProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final days = ref.watch(_rangeProvider);
  final supabase = Supabase.instance.client;
  final res = await supabase.rpc('admin_daily_revenue', params: {'p_days': days});
  return List<Map<String, dynamic>>.from(res as List);
});

double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(dailyRevenueProvider);
    final range = ref.watch(_rangeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue Reports'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(dailyRevenueProvider)),
        ],
      ),
      body: dataAsync.when(
        data: (rows) {
          final totalGross = rows.fold<double>(0, (s, r) => s + _n(r['gross']));
          final totalComm = rows.fold<double>(0, (s, r) => s + _n(r['commission']));
          final totalPayout = rows.fold<double>(0, (s, r) => s + _n(r['payouts']));
          final totalBookings = rows.fold<int>(0, (s, r) => s + ((r['bookings'] as num?)?.toInt() ?? 0));
          final maxComm = rows.fold<double>(0, (m, r) => _n(r['commission']) > m ? _n(r['commission']) : m);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Range: '),
                  const SizedBox(width: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7d')),
                      ButtonSegment(value: 30, label: Text('30d')),
                      ButtonSegment(value: 90, label: Text('90d')),
                    ],
                    selected: {range},
                    onSelectionChanged: (s) => ref.read(_rangeProvider.notifier).state = s.first,
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Export CSV'),
                    onPressed: () => _exportCsv(context, rows),
                  ),
                ]),
                const SizedBox(height: 24),
                Wrap(spacing: 20, runSpacing: 20, children: [
                  _Stat('Commission', '৳${totalComm.toStringAsFixed(2)}', Colors.green),
                  _Stat('Gross Volume', '৳${totalGross.toStringAsFixed(2)}', Colors.teal),
                  _Stat('Owner Payouts', '৳${totalPayout.toStringAsFixed(2)}', Colors.indigo),
                  _Stat('Bookings', '$totalBookings', Colors.blue),
                ]),
                const SizedBox(height: 32),
                Text('Daily Commission', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _BarChart(rows: rows, maxVal: maxComm),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, List<Map<String, dynamic>> rows) async {
    final sb = StringBuffer('day,bookings,gross,commission,payouts\n');
    for (final r in rows) {
      sb.writeln('${r['day']},${r['bookings']},${r['gross']},${r['commission']},${r['payouts']}');
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('CSV copied to clipboard'),
          content: SizedBox(
            width: 500,
            child: SelectableText(sb.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    }
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final double maxVal;
  const _BarChart({required this.rows, required this.maxVal});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('No data.');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 220,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: rows.map((r) {
                final v = _n(r['commission']);
                final h = maxVal <= 0 ? 0.0 : (v / maxVal) * 160.0;
                final day = (r['day'] ?? '').toString();
                final label = day.length >= 10 ? day.substring(5) : day; // MM-DD
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(v > 0 ? v.toStringAsFixed(0) : '', style: const TextStyle(fontSize: 9)),
                    const SizedBox(height: 2),
                    Tooltip(
                      message: '$day\n৳${v.toStringAsFixed(2)}',
                      child: Container(
                        width: 16,
                        height: h < 2 && v > 0 ? 2 : h,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    RotatedBox(quarterTurns: 3, child: Text(label, style: const TextStyle(fontSize: 8))),
                  ]),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
