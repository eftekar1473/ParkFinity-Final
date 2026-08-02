import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../shared/data/repositories/bookings_repository.dart';
import '../../data/ai_recommendation_service.dart';

/// Builds a [RiderHistoryProfile] from the signed-in rider's past bookings.
/// Used by the recommender to bias ranking toward previously-booked owners
/// and the rider's typical price band. Empty profile if not signed in / no
/// history — the recommender then simply ignores the history term.
final riderHistoryProfileProvider =
    FutureProvider<RiderHistoryProfile>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return const RiderHistoryProfile();

  final bookings =
      await ref.watch(bookingsRepositoryProvider).getRiderBookings(user.id);
  if (bookings.isEmpty) return const RiderHistoryProfile();

  final ownerIds = <String>{};
  final hourlyPrices = <double>[];
  for (final b in bookings) {
    final listing = b.listing;
    if (listing != null) {
      ownerIds.add(listing.ownerId);
      if (listing.hourlyRate != null && listing.hourlyRate! > 0) {
        hourlyPrices.add(listing.hourlyRate!);
      }
    }
  }

  final avgPrice = hourlyPrices.isEmpty
      ? null
      : hourlyPrices.reduce((a, b) => a + b) / hourlyPrices.length;

  return RiderHistoryProfile(
    ownerIds: ownerIds,
    avgHourlyPrice: avgPrice,
    bookingCount: bookings.length,
  );
});
