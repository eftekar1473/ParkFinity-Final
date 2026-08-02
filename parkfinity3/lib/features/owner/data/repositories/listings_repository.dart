import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing_model.dart';

final listingsRepositoryProvider = Provider<ListingsRepository>((ref) {
  return ListingsRepository(Supabase.instance.client);
});

class ListingsRepository {
  final SupabaseClient _client;

  ListingsRepository(this._client);

  Future<ListingModel> createListing(ListingModel listing) async {
    final response = await _client
        .from('listings')
        .insert(listing.toJson())
        .select()
        .single();
    return ListingModel.fromJson(response);
  }

  Future<List<ListingModel>> getOwnerListings(String ownerId) async {
    final response = await _client
        .from('listings')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    
    return (response as List).map((e) => ListingModel.fromJson(e)).toList();
  }

  Future<List<ListingModel>> getAllActiveListings() async {
    final response = await _client
        .from('listings')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
        
    return (response as List).map((e) => ListingModel.fromJson(e)).toList();
  }

  Future<ListingModel> updateListing(ListingModel listing) async {
    if (listing.id == null) throw Exception('Listing ID cannot be null for updates');
    
    final response = await _client
        .from('listings')
        .update(listing.toJson())
        .eq('id', listing.id!)
        .select()
        .single();
        
    return ListingModel.fromJson(response);
  }

  Future<void> updateListingStatus(String id, bool isActive) async {
    await _client
        .from('listings')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  Future<void> deleteListing(String id) async {
    await _client.from('listings').delete().eq('id', id);
  }
}
