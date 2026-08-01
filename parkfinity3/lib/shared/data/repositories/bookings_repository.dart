import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';

final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  return BookingsRepository(Supabase.instance.client);
});

class BookingsRepository {
  final SupabaseClient _client;

  BookingsRepository(this._client);

  Future<BookingModel> createBooking(BookingModel booking) async {
    // 1. Create the booking
    final response = await _client
        .from('bookings')
        .insert(booking.toJson())
        .select()
        .single();
    
    final createdBooking = BookingModel.fromJson(response);

    // 2. Try to deduct funds
    try {
      await _client.rpc('deduct_funds', params: {
        'user_id_param': booking.riderId,
        'amount_param': booking.totalAmount,
        'booking_id_param': createdBooking.id,
      });
    } catch (e) {
      // If deduction fails, cancel the booking
      await _client
          .from('bookings')
          .update({'status': 'Cancelled'})
          .eq('id', createdBooking.id!);
      throw Exception('Payment failed: Insufficient wallet balance.');
    }

    return createdBooking;
  }

  Future<List<BookingModel>> getRiderBookings(String riderId) async {
    final response = await _client
        .from('bookings')
        .select('*, listings(*)') // Join with listings
        .eq('rider_id', riderId)
        .order('created_at', ascending: false);
        
    return (response as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<List<BookingModel>> getOwnerBookings(String ownerId) async {
    // This requires a join through listings, or fetching listings first
    // For simplicity, we can fetch all bookings where listing_id is in owner's listings
    final listingsResponse = await _client
        .from('listings')
        .select('id')
        .eq('owner_id', ownerId);
        
    final listingIds = (listingsResponse as List).map((l) => l['id'] as String).toList();
    
    if (listingIds.isEmpty) return [];

    final response = await _client
        .from('bookings')
        .select('*, profiles(*)') // Join with profiles to get rider details
        .inFilter('listing_id', listingIds)
        .order('created_at', ascending: false);
        
    return (response as List).map((e) => BookingModel.fromJson(e)).toList();
  }
}
