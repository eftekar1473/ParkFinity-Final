import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class TransactionModel {
  final String id;
  final double amount;
  final String type;
  final String status;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      type: json['type'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class WalletState {
  final double balance;
  final List<TransactionModel> transactions;

  WalletState({
    required this.balance,
    required this.transactions,
  });
}

class WalletController extends AsyncNotifier<WalletState> {
  final _supabase = Supabase.instance.client;

  @override
  FutureOr<WalletState> build() async {
    return _fetchWalletData();
  }

  Future<WalletState> _fetchWalletData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return WalletState(balance: 0.0, transactions: []);
    }

    try {
      // Fetch balance
      final profileResponse = await _supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('id', userId)
          .maybeSingle();
      
      final balance = profileResponse == null ? 0.0 : (profileResponse['wallet_balance'] as num?)?.toDouble() ?? 0.0;

      // Fetch transactions
      final transactionsResponse = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final transactions = (transactionsResponse as List)
          .map((data) => TransactionModel.fromJson(data))
          .toList();

      return WalletState(balance: balance, transactions: transactions);
    } catch (e) {
      throw Exception('Failed to load wallet data: $e');
    }
  }

  /// Credit a top-up. Only the gateway's `val_id` is sent — the server asks
  /// SSLCommerz for the real amount, so the client cannot name its own.
  /// Returns false when the payment could not be verified.
  Future<bool> creditTopUp(String valId) async {
    state = const AsyncValue.loading();

    try {
      final res = await _supabase.functions.invoke(
        'wallet-topup',
        body: {'val_id': valId},
      );
      final ok = (res.data as Map?)?['credited'] == true;
      state = AsyncValue.data(await _fetchWalletData());
      return ok;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

final walletControllerProvider = AsyncNotifierProvider<WalletController, WalletState>(
  () => WalletController(),
);
