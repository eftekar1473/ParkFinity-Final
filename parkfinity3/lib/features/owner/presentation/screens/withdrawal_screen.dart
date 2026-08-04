import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/withdrawal_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Owner payout: shows wallet balance, a request form, and past requests.
class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankController = TextEditingController();

  double _balance = 0;
  bool _loading = true;
  bool _submitting = false;
  List<WithdrawalModel> _history = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(withdrawalRepositoryProvider);
      final results = await Future.wait([
        repo.currentBalance(),
        repo.myWithdrawals(),
      ]);
      setState(() {
        _balance = results[0] as double;
        _history = results[1] as List<WithdrawalModel>;
      });
    } catch (e) {
      if (mounted) _snack(AppLocalizations.of(context).failedToLoad('$e'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text);
    setState(() => _submitting = true);
    try {
      await ref
          .read(withdrawalRepositoryProvider)
          .requestWithdrawal(amount, _bankController.text.trim());
      _amountController.clear();
      _bankController.clear();
      if (mounted) _snack(AppLocalizations.of(context).withdrawalRequested);
      await _refresh();
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Completed':
        return Colors.green;
      case 'Rejected':
        return Theme.of(context).colorScheme.error;
      case 'Approved':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.withdrawEarningsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    color: theme.colorScheme.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.availableBalance,
                              style: TextStyle(
                                  color: theme.colorScheme.onPrimary
                                      .withValues(alpha: 0.75))),
                          const SizedBox(height: 8),
                          Text('৳ ${_balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: l10n.amountBdt,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.attach_money)),
                          validator: (v) {
                            final a = double.tryParse(v ?? '');
                            if (a == null || a <= 0) return l10n.enterValidAmount;
                            if (a > _balance) return l10n.exceedsBalance;
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _bankController,
                          maxLines: 2,
                          decoration: InputDecoration(
                              labelText: l10n.payoutMethod,
                              hintText: l10n.payoutHint,
                              border: const OutlineInputBorder()),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? l10n.required : null,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16)),
                          child: _submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : Text(l10n.requestWithdrawal),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(l10n.history,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.noWithdrawals,
                          style: TextStyle(color: theme.hintColor)),
                    )
                  else
                    ..._history.map((w) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _statusColor(w.status).withValues(alpha: 0.15),
                            child: Icon(Icons.payments,
                                color: _statusColor(w.status)),
                          ),
                          title: Text('৳ ${w.amount.toStringAsFixed(2)}'),
                          subtitle: Text(w.bankAccountDetails,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text(w.status,
                              style: TextStyle(
                                  color: _statusColor(w.status),
                                  fontWeight: FontWeight.bold)),
                        )),
                ],
              ),
            ),
    );
  }
}
