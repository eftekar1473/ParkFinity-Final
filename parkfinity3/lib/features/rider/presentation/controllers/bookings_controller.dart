import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/data/models/booking_model.dart';
import '../../../../shared/data/repositories/bookings_repository.dart';
import '../../../auth/data/auth_repository.dart';

final bookingsControllerProvider = AsyncNotifierProvider<BookingsController, void>(
  BookingsController.new,
);

class BookingsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // Initial state is just void/ready
  }

  Future<void> createBooking(BookingModel booking) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(bookingsRepositoryProvider);
      await repository.createBooking(booking);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      throw e; // rethrow to let UI catch it
    }
  }
}
