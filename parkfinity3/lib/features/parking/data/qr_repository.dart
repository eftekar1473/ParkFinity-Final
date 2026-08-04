import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a check_in / check_out RPC call.
class ScanResult {
  final bool ok;
  final String message;
  final String? bookingId;
  final DateTime? endTime;
  final double overstayCharge;

  const ScanResult({
    required this.ok,
    required this.message,
    this.bookingId,
    this.endTime,
    this.overstayCharge = 0,
  });

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
        ok: j['ok'] == true,
        message: (j['msg'] as String?) ?? '',
        bookingId: j['booking_id'] as String?,
        endTime: j['end_time'] != null
            ? DateTime.tryParse(j['end_time'].toString())
            : null,
        overstayCharge: (j['overstay_charge'] as num?)?.toDouble() ?? 0,
      );
}

final qrRepositoryProvider = Provider<QrRepository>((ref) {
  return QrRepository(Supabase.instance.client);
});

class QrRepository {
  final SupabaseClient _client;
  QrRepository(this._client);

  /// The payload printed on the owner's poster.
  static const scheme = 'parkfinity://spot?t=';

  /// Accepts the full deep-link payload, a bare UUID, or the 6-char short code.
  static String normalizeToken(String raw) {
    var t = raw.trim();
    final idx = t.indexOf('t=');
    if (idx >= 0) t = t.substring(idx + 2);
    // Strip anything after the token (extra query params, whitespace).
    t = t.split('&').first.trim();
    return t;
  }

  Future<ScanResult> checkIn(String rawToken) async {
    final res = await _client
        .rpc('check_in', params: {'p_token': normalizeToken(rawToken)});
    return ScanResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<ScanResult> checkOut(String rawToken) async {
    final res = await _client
        .rpc('check_out', params: {'p_token': normalizeToken(rawToken)});
    return ScanResult.fromJson(Map<String, dynamic>.from(res as Map));
  }
}
