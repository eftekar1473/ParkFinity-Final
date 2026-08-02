import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final platformSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  final row = await supabase.from('platform_settings').select().eq('id', true).single();
  return Map<String, dynamic>.from(row);
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};
  bool _saving = false;
  bool _loaded = false;

  // key -> (label, helper). All numeric.
  static const _fields = {
    'commission_rate': ['Commission rate (0-1)', 'e.g. 0.10 = 10% platform cut'],
    'peak_multiplier': ['Peak multiplier', 'applied during high-demand hours'],
    'weekend_multiplier': ['Weekend multiplier', 'Fri/Sat surcharge'],
    'overstay_multiplier': ['Overstay multiplier', 'penalty = hours × rate × this'],
    'refund_full_hours': ['Full-refund hours', 'cancel this many hrs before start = full'],
    'refund_partial_pct': ['Partial refund pct (0-1)', 'inside window = this fraction back'],
  };

  void _hydrate(Map<String, dynamic> s) {
    if (_loaded) return;
    for (final k in _fields.keys) {
      _c[k] = TextEditingController(text: '${s[k] ?? ''}');
    }
    _loaded = true;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final update = <String, dynamic>{};
      for (final k in _fields.keys) {
        update[k] = num.parse(_c[k]!.text.trim());
      }
      update['updated_at'] = DateTime.now().toIso8601String();
      await Supabase.instance.client.from('platform_settings').update(update).eq('id', true);
      ref.invalidate(platformSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(platformSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Platform Settings')),
      body: async.when(
        data: (s) {
          _hydrate(s);
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Commission, pricing multipliers & refund policy',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text('These drive server-side booking pricing and refunds.',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      ..._fields.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: TextFormField(
                              controller: _c[e.key],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: e.value[0],
                                helperText: e.value[1],
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                if (num.tryParse(v.trim()) == null) return 'Must be a number';
                                return null;
                              },
                            ),
                          )),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: const Text('Save Settings'),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ],
                  ),
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
