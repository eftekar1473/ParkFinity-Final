import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';

final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  return BookingsRepository(Supabase.instance.client);
});

/// Request payload for a server-side booking. Money, slot lock and pricing are
/// all decided by the create-booking Edge Function — the client only supplies intent.
class BookingRequest {
  final String riderId;
  final String listingId;
  final String vehicleId;
  final String vehicleType;
  final String durationType; // Hourly|Daily|Weekly|Monthly|Yearly
  final int durationCount;
  final DateTime? startTime;

  BookingRequest({
    required this.riderId,
    required this.listingId,
    required this.vehicleId,
    required this.vehicleType,
    required this.durationType,
    required this.durationCount,
    this.startTime,
  });

  Map<String, dynamic> toBody() => {
        'rider_id': riderId,
        'listing_id': listingId,
        'vehicle_id': vehicleId,
        'vehicle_type': vehicleType,
        'duration_type': durationType,
        'duration_count': durationCount,
        if (startTime != null) 'start_time': startTime!.toUtc().toIso8601String(),
      };
}

class BookingsRepository {
  final SupabaseClient _client;

  BookingsRepository(this._client);

  /// Create a booking through the server (atomic slot lock + wallet charge + pricing).
  Future<BookingModel> createBooking(BookingRequest req) async {
    final res = await _client.functions.invoke('create-booking', body: req.toBody());
    final data = res.data;
    if (res.status >= 400 || data is! Map || data['booking'] == null) {
      final msg = (data is Map ? data['error'] : null) ?? 'Booking failed';
      throw Exception(msg);
    }
    return BookingModel.fromJson(Map<String, dynamic>.from(data['booking']));
  }

  /// Extend an active booking by extra duration (server prices + charges + guards).
  Future<BookingModel> extendBooking({
    required String bookingId,
    required String riderId,
    required String durationType,
    required int durationCount,
  }) async {
    final res = await _client.functions.invoke('extend-booking', body: {
      'booking_id': bookingId,
      'rider_id': riderId,
      'duration_type': durationType,
      'duration_count': durationCount,
    });
    final data = res.data;
    if (res.status >= 400 || data is! Map || data['booking'] == null) {
      final msg = (data is Map ? data['error'] : null) ?? 'Extension failed';
      throw Exception(msg);
    }
    return BookingModel.fromJson(Map<String, dynamic>.from(data['booking']));
  }

  /// Cancel atomically (status + slot release + policy refund) via RPC.
  /// Returns the server message (e.g. "Refunded 250" or "Cancelled (no refund)").
  Future<String> cancelBooking(String bookingId, String actorId) async {
    final rows = await _client.rpc('cancel_booking', params: {
      'p_booking': bookingId,
      'p_actor': actorId,
    });
    final row = (rows is List && rows.isNotEmpty) ? rows.first as Map : null;
    if (row == null || row['ok'] != true) {
      throw Exception(row?['msg'] ?? 'Cancellation failed');
    }
    return (row['msg'] ?? 'Cancelled').toString();
  }

  /// Complete a booking: status Completed + credit owner earnings (server-side).
  Future<String> completeBooking(String bookingId) async {
    final rows = await _client.rpc('complete_booking', params: {'p_booking': bookingId});
    final row = (rows is List && rows.isNotEmpty) ? rows.first as Map : null;
    if (row == null || row['ok'] != true) {
      throw Exception(row?['msg'] ?? 'Completion failed');
    }
    return (row['msg'] ?? 'Completed').toString();
  }

  Future<List<BookingModel>> getRiderBookings(String riderId) async {
    final response = await _client
        .from('bookings')
        .select('*, listings(*)')
        .eq('rider_id', riderId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<List<BookingModel>> getOwnerBookings(String ownerId) async {
    final listingsResponse =
        await _client.from('listings').select('id').eq('owner_id', ownerId);
    final listingIds =
        (listingsResponse as List).map((l) => l['id'] as String).toList();
    if (listingIds.isEmpty) return [];

    final response = await _client
        .from('bookings')
        // listings() is needed for the details screen (address, coords, phone).
        .select('*, profiles(*), listings(*)')
        .inFilter('listing_id', listingIds)
        .order('created_at', ascending: false);
    return (response as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  /// Single booking by id — used when a notification carries a `booking_id`
  /// and we need the full row to push the details screen.
  Future<BookingModel?> getBooking(String bookingId) async {
    final rows = await _client
        .from('bookings')
        .select('*, profiles(*), listings(*)')
        .eq('id', bookingId)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return BookingModel.fromJson(rows.first);
  }
}
