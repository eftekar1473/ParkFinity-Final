import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final withdrawalRepositoryProvider = Provider<WithdrawalRepository>((ref) {
  return WithdrawalRepository(Supabase.instance.client);
});

class WithdrawalModel {
  final String id;
  final double amount;
  final String bankAccountDetails;
  final String status; // Pending|Approved|Rejected|Paid
  final DateTime createdAt;

  WithdrawalModel({
    required this.id,
    required this.amount,
    required this.bankAccountDetails,
    required this.status,
    required this.createdAt,
  });

  factory WithdrawalModel.fromJson(Map<String, dynamic> j) => WithdrawalModel(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        bankAccountDetails: j['bank_account_details'] as String? ?? '',
        status: j['status'] as String? ?? 'Pending',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class WithdrawalRepository {
  final SupabaseClient _client;
  WithdrawalRepository(this._client);

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Not logged in');
    return id;
  }

  Future<double> currentBalance() async {
    final res = await _client
        .from('profiles')
        .select('wallet_balance')
        .eq('id', _uid)
        .maybeSingle();
    return (res?['wallet_balance'] as num?)?.toDouble() ?? 0;
  }

  Future<List<WithdrawalModel>> myWithdrawals() async {
    final res = await _client
        .from('withdrawals')
        .select()
        .eq('owner_id', _uid)
        .order('created_at', ascending: false);
    return (res as List).map((e) => WithdrawalModel.fromJson(e)).toList();
  }

  /// Requests a payout: deducts the amount from the wallet (held) and records a
  /// Pending withdrawal for admin approval. Admin rejection restores funds.
  /// Atomic — balance check + deduct + insert happen server-side in one txn.
  Future<void> requestWithdrawal(double amount, String bankDetails) async {
    if (amount <= 0) throw Exception('Amount must be greater than zero.');
    await _client.rpc('request_withdrawal', params: {
      'p_owner': _uid,
      'p_amount': amount,
      'p_bank': bankDetails,
    });
  }
}
