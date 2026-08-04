import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../controllers/wallet_provider.dart';
import '../../../shared/data/my_profile_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'package:flutter_sslcommerz/model/SSLCommerzInitialization.dart';
import 'package:flutter_sslcommerz/model/SSLCTransactionInfoModel.dart';
import 'package:flutter_sslcommerz/model/SSLCCustomerInfoInitializer.dart';
import 'package:flutter_sslcommerz/model/SSLCEMITransactionInitializer.dart';
import 'package:flutter_sslcommerz/model/SSLCSdkType.dart';
import 'package:flutter_sslcommerz/model/SSLCurrencyType.dart';
import 'package:flutter_sslcommerz/sslcommerz.dart';

/// One wallet for both roles, but the actions differ: riders top up to pay for
/// bookings, owners only ever take money out. Showing "Add Funds" to an owner
/// implies they must fund their own payouts, which is wrong.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addFunds(String amountText, BuildContext dialogContext) async {
    final l10n = AppLocalizations.of(context);
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.enterValidAmount)));
      return;
    }

    Navigator.of(dialogContext).pop();

    final profile = ref.read(currentProfileProvider).value;
    final storeId = dotenv.env['SSLCOMMERZ_STORE_ID'] ?? 'your_store_id';
    final storePass =
        dotenv.env['SSLCOMMERZ_STORE_PASSWD'] ?? 'your_store_passwd';
    final txnId = "TXN_${DateTime.now().millisecondsSinceEpoch}";

    Sslcommerz sslcommerz = Sslcommerz(
      initializer: SSLCommerzInitialization(
        multi_card_name: 'internetbank',
        currency: SSLCurrencyType.BDT,
        product_category: 'Wallet',
        sdkType: SSLCSdkType.TESTBOX,
        store_id: storeId,
        store_passwd: storePass,
        total_amount: amount,
        tran_id: txnId,
      ),
    );

    sslcommerz.addCustomerInfoInitializer(
      customerInfoInitializer: SSLCCustomerInfoInitializer(
        customerName: profile?.displayName ?? 'Parkfinity User',
        customerEmail: profile?.email ?? 'user@parkfinity.com',
        customerAddress1: 'Dhaka',
        customerCity: 'Dhaka',
        customerState: 'Dhaka',
        customerPostCode: '1000',
        customerCountry: 'Bangladesh',
        customerPhone: profile?.phoneNumber ?? '01700000000',
      ),
    );

    sslcommerz.addEMITransactionInitializer(
        sslcemiTransactionInitializer:
            SSLCEMITransactionInitializer(emi_options: 0));

    try {
      SSLCTransactionInfoModel result = await sslcommerz.payNow();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final status = result.status?.toUpperCase();

      if (status == 'VALID' || status == 'VALIDATED') {
        // Credit server-side from the gateway's val_id. The amount is read
        // back from SSLCommerz, never taken from this screen.
        final valId = result.valId;
        final credited = valId == null
            ? false
            : await ref
                .read(walletControllerProvider.notifier)
                .creditTopUp(valId);
        if (!mounted) return;
        ref.invalidate(currentProfileProvider);
        messenger.showSnackBar(SnackBar(
          content: Text(credited ? l10n.fundsAdded : l10n.paymentFailed),
        ));
      } else if (status == 'FAILED') {
        messenger.showSnackBar(SnackBar(content: Text(l10n.paymentFailed)));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.paymentCancelled)));
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.paymentError),
          content: Text(e.toString()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok))
          ],
        ),
      );
    }
  }

  void _showAddFundsDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.addFunds),
        content: TextField(
          controller: _amountController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.amountBdtWallet,
            prefixText: '৳ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => _addFunds(_amountController.text, dialogContext),
            child: Text(l10n.add),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final walletStateAsync = ref.watch(walletControllerProvider);
    final isOwner = ref.watch(currentProfileProvider).value?.isOwner ?? false;
    final money = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final stamp = DateFormat('d MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwner ? l10n.earnings : l10n.myWallet),
        centerTitle: true,
      ),
      body: walletStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('${l10n.error}: $error')),
        data: (state) {
          // Lifetime credited earnings, for the owner header.
          final earned = state.transactions
              .where((t) => t.type == 'earning' && t.status != 'failed')
              .fold<double>(0, (a, t) => a + t.amount);
          final pendingOut = state.transactions
              .where((t) => t.type == 'withdrawal' && t.status == 'pending')
              .fold<double>(0, (a, t) => a + t.amount);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(walletControllerProvider);
              ref.invalidate(currentProfileProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.72),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.availableBalance,
                        style: TextStyle(
                            color: theme.colorScheme.onPrimary
                                .withValues(alpha: 0.75),
                            fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        money.format(state.balance),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isOwner) ...[
                        const SizedBox(height: 12),
                        _MiniStat(
                            label: l10n.totalEarnings,
                            value: money.format(earned)),
                        if (pendingOut > 0)
                          _MiniStat(
                              label: l10n.pendingWithdrawals,
                              value: money.format(pendingOut)),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          // Owners cash out; riders top up. Never both.
                          onPressed: isOwner
                              ? () => context.push('/withdraw')
                              : _showAddFundsDialog,
                          icon: Icon(isOwner
                              ? Icons.account_balance
                              : Icons.add),
                          label:
                              Text(isOwner ? l10n.withdraw : l10n.addFunds),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.onPrimary,
                            foregroundColor: theme.colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isOwner ? l10n.ownerWalletNote : l10n.riderWalletNote,
                  style: TextStyle(color: theme.hintColor, fontSize: 12),
                ),
                const SizedBox(height: 24),
                Text(l10n.transactionHistory,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (state.transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(child: Text(l10n.noTransactions)),
                  )
                else
                  ...state.transactions.map((tx) {
                    final isCredit =
                        tx.type == 'deposit' || tx.type == 'earning';
                    final color =
                        isCredit ? Colors.green : theme.colorScheme.error;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Icon(
                            isCredit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: color,
                          ),
                        ),
                        title:
                            Text(tx.type.replaceAll('_', ' ').toUpperCase()),
                        subtitle: Text(
                            '${stamp.format(tx.createdAt.toLocal())} · ${tx.status}'),
                        trailing: Text(
                          '${isCredit ? '+' : '-'}${money.format(tx.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: onPrimary.withValues(alpha: 0.75), fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
