import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../controllers/wallet_provider.dart';
import 'package:flutter_sslcommerz/model/SSLCommerzInitialization.dart';
import 'package:flutter_sslcommerz/model/SSLCTransactionInfoModel.dart';
import 'package:flutter_sslcommerz/model/SSLCCustomerInfoInitializer.dart';
import 'package:flutter_sslcommerz/model/SSLCEMITransactionInitializer.dart';
import 'package:flutter_sslcommerz/model/SSLCSdkType.dart';
import 'package:flutter_sslcommerz/model/SSLCurrencyType.dart';
import 'package:flutter_sslcommerz/sslcommerz.dart';

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
    final amount = double.tryParse(amountText);
    
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }
    
    // Close the input dialog using its own context
    Navigator.of(dialogContext).pop();

    final storeId = dotenv.env['SSLCOMMERZ_STORE_ID'] ?? 'your_store_id';
    final storePass = dotenv.env['SSLCOMMERZ_STORE_PASSWD'] ?? 'your_store_passwd';
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
        customerName: 'Parkfinity User',
        customerEmail: 'user@parkfinity.com',
        customerAddress1: 'Dhaka',
        customerCity: 'Dhaka',
        customerState: 'Dhaka',
        customerPostCode: '1000',
        customerCountry: 'Bangladesh',
        customerPhone: '01700000000',
      ),
    );

    sslcommerz.addEMITransactionInitializer(
      sslcemiTransactionInitializer: SSLCEMITransactionInitializer(emi_options: 0)
    );

    try {
      SSLCTransactionInfoModel result = await sslcommerz.payNow();
      if (!mounted) return;

      if (result.status != null && (result.status!.toUpperCase() == 'VALID' || result.status!.toUpperCase() == 'VALIDATED')) {
        await ref.read(walletControllerProvider.notifier).addFundsSuccess(amount, txnId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funds added successfully!')),
        );
      } else if (result.status != null && result.status!.toUpperCase() == 'FAILED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment cancelled or incomplete.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
          ],
        ),
      );
    }
  }

  void _showAddFundsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Funds'),
          content: TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (BDT)',
              prefixText: '৳ ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _addFunds(_amountController.text, dialogContext),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletStateAsync = ref.watch(walletControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        centerTitle: true,
      ),
      body: walletStateAsync.when(
        data: (state) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(walletControllerProvider),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Balance Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Balance',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '৳ ${state.balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showAddFundsDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Funds'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Transaction History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (state.transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text('No transactions yet.'),
                    ),
                  )
                else
                  ...state.transactions.map((tx) {
                    final isDeposit = tx.type == 'deposit' || tx.type == 'earning';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDeposit ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                          child: Icon(
                            isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isDeposit ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(tx.type.replaceAll('_', ' ').toUpperCase()),
                        subtitle: Text(tx.createdAt.toLocal().toString().split('.')[0]),
                        trailing: Text(
                          '${isDeposit ? '+' : '-'}৳${tx.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDeposit ? Colors.green : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
