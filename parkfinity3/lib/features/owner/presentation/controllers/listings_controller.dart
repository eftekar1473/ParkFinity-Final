import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/listing_model.dart';
import '../../data/repositories/listings_repository.dart';
import '../../../auth/data/auth_repository.dart';

// Provider for all active listings (for Riders)
final allActiveListingsProvider = FutureProvider<List<ListingModel>>((ref) async {
  final repository = ref.watch(listingsRepositoryProvider);
  return repository.getAllActiveListings();
});

/// Realtime stream of active listings. Emits a fresh list whenever any
/// listing row changes (e.g. slot_available decremented by a booking),
/// so the map availability updates live without a manual refresh.
final activeListingsStreamProvider =
    StreamProvider<List<ListingModel>>((ref) {
  final client = Supabase.instance.client;
  return client
      .from('listings')
      .stream(primaryKey: ['id'])
      .map((rows) => rows
          .where((r) => r['is_active'] == true)
          .map((e) => ListingModel.fromJson(e))
          .toList());
});

// Provider for owner's own listings
final myListingsProvider = AsyncNotifierProvider<MyListingsController, List<ListingModel>>(
  MyListingsController.new,
);

class MyListingsController extends AsyncNotifier<List<ListingModel>> {
  @override
  Future<List<ListingModel>> build() async {
    return _fetchMyListings();
  }

  Future<List<ListingModel>> _fetchMyListings() async {
    final authState = ref.watch(authStateChangesProvider);
    final user = authState.value?.session?.user;
    if (user == null) return [];

    final repository = ref.watch(listingsRepositoryProvider);
    return repository.getOwnerListings(user.id);
  }

  Future<void> addListing(ListingModel listing) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(listingsRepositoryProvider);
      await repository.createListing(listing);
      
      // Invalidate the public provider so Riders see the new listing
      ref.invalidate(allActiveListingsProvider);
      
      final updated = await _fetchMyListings();
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> editListing(ListingModel listing) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(listingsRepositoryProvider);
      await repository.updateListing(listing);

      ref.invalidate(allActiveListingsProvider);
      final updated = await _fetchMyListings();
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateListingStatus(String id, bool isActive) async {
    try {
      final repository = ref.read(listingsRepositoryProvider);
      await repository.updateListingStatus(id, isActive);
      
      ref.invalidate(allActiveListingsProvider);
      final updated = await _fetchMyListings();
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteListing(String id) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(listingsRepositoryProvider);
      await repository.deleteListing(id);
      
      ref.invalidate(allActiveListingsProvider);
      final updated = await _fetchMyListings();
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
