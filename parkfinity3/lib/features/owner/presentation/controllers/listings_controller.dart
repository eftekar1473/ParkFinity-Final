import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/listing_model.dart';
import '../../data/repositories/listings_repository.dart';
import '../../../auth/data/auth_repository.dart';

// Provider for all active listings (for Riders)
final allActiveListingsProvider = FutureProvider<List<ListingModel>>((ref) async {
  final repository = ref.watch(listingsRepositoryProvider);
  return repository.getAllActiveListings();
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
    state = await AsyncValue.guard(() async {
      final repository = ref.read(listingsRepositoryProvider);
      await repository.createListing(listing);
      
      // Invalidate the public provider so Riders see the new listing
      ref.invalidate(allActiveListingsProvider);
      
      return _fetchMyListings();
    });
  }

  Future<void> deleteListing(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(listingsRepositoryProvider);
      await repository.deleteListing(id);
      
      ref.invalidate(allActiveListingsProvider);
      return _fetchMyListings();
    });
  }
}
