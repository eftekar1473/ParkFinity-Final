import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/data/models/booking_model.dart';
import '../../../../shared/data/repositories/bookings_repository.dart';

final bookingsControllerProvider = AsyncNotifierProvider<BookingsController, void>(
  BookingsController.new,
);

class BookingsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<BookingModel> createBooking(BookingRequest req) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(bookingsRepositoryProvider);
      final booking = await repository.createBooking(req);
      state = const AsyncValue.data(null);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<BookingModel> extendBooking({
    required String bookingId,
    required String riderId,
    required String durationType,
    required int durationCount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final booking = await ref.read(bookingsRepositoryProvider).extendBooking(
            bookingId: bookingId,
            riderId: riderId,
            durationType: durationType,
            durationCount: durationCount,
          );
      state = const AsyncValue.data(null);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<String> cancelBooking(String bookingId, String actorId) async {
    state = const AsyncValue.loading();
    try {
      final msg = await ref.read(bookingsRepositoryProvider).cancelBooking(bookingId, actorId);
      state = const AsyncValue.data(null);
      return msg;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<String> completeBooking(String bookingId) async {
    state = const AsyncValue.loading();
    try {
      final msg = await ref.read(bookingsRepositoryProvider).completeBooking(bookingId);
      state = const AsyncValue.data(null);
      return msg;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
