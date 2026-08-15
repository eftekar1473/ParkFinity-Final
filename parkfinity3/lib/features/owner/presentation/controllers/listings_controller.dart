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

final myListingsProvider = StreamProvider<List<ListingModel>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.value?.session?.user;
  if (user == null) return Stream.value([]);
  
  return Supabase.instance.client
      .from('listings')
      .stream(primaryKey: ['id'])
      .eq('owner_id', user.id)
      .map((rows) {
        final list = rows.map((e) => ListingModel.fromJson(e)).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });
});

final myListingsControllerProvider = Provider<MyListingsController>((ref) => MyListingsController(ref));

class MyListingsController {
  final Ref ref;
  MyListingsController(this.ref);

  Future<void> addListing(ListingModel listing) async {
    final repository = ref.read(listingsRepositoryProvider);
    await repository.createListing(listing);
    ref.invalidate(allActiveListingsProvider);
  }

  Future<void> editListing(ListingModel listing) async {
    final repository = ref.read(listingsRepositoryProvider);
    await repository.updateListing(listing);
    ref.invalidate(allActiveListingsProvider);
  }

  Future<void> updateListingStatus(String id, bool isActive) async {
    final repository = ref.read(listingsRepositoryProvider);
    await repository.updateListingStatus(id, isActive);
    ref.invalidate(allActiveListingsProvider);
  }

  Future<void> deleteListing(String id) async {
    try {
      final repository = ref.read(listingsRepositoryProvider);
      await repository.deleteListing(id);
      ref.invalidate(allActiveListingsProvider);
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw Exception('Cannot delete this listing because it has associated bookings. Please pause it instead.');
      }
      rethrow;
    }
  }
}
