import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/data/models/booking_model.dart';
import '../../../../shared/data/repositories/bookings_repository.dart';
import '../../../auth/data/auth_repository.dart';

final ownerBookingsProvider = StreamProvider.autoDispose<List<BookingModel>>((ref) async* {
  final user = ref.watch(authStateChangesProvider).value?.session?.user;
  if (user == null) {
    yield [];
    return;
  }

  final repository = ref.watch(bookingsRepositoryProvider);
  yield await repository.getOwnerBookings(user.id);

  await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
    yield await repository.getOwnerBookings(user.id);
  }
});
