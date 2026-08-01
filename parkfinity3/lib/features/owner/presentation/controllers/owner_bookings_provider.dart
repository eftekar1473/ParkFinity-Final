import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/data/models/booking_model.dart';
import '../../../../shared/data/repositories/bookings_repository.dart';
import '../../../auth/data/auth_repository.dart';

final ownerBookingsProvider = FutureProvider.autoDispose<List<BookingModel>>((ref) async {
  final user = ref.watch(authStateChangesProvider).value?.session?.user;
  if (user == null) return [];

  final repository = ref.watch(bookingsRepositoryProvider);
  return await repository.getOwnerBookings(user.id);
});
