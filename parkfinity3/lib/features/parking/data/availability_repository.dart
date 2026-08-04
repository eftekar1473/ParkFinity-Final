import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Key for an availability lookup. Times are compared as UTC instants so the
/// same window asked twice hits the same provider cache entry.
class AvailabilityQuery {
  final String listingId;
  final String vehicleType;
  final DateTime start;
  final DateTime end;

  AvailabilityQuery({
    required this.listingId,
    required this.vehicleType,
    required DateTime start,
    required DateTime end,
  })  : start = start.toUtc(),
        end = end.toUtc();

  @override
  bool operator ==(Object other) =>
      other is AvailabilityQuery &&
      other.listingId == listingId &&
      other.vehicleType == vehicleType &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(listingId, vehicleType, start, end);
}

/// How many slots of one vehicle type are free for the WHOLE requested window.
/// Backed by `available_qty`, which counts peak concurrent bookings at every
/// booking boundary inside the window rather than trusting a live counter — so a
/// spot booked 2pm-3pm is still sellable for 5pm-6pm.
final availableQtyProvider =
    FutureProvider.family<int, AvailabilityQuery>((ref, q) async {
  final res = await Supabase.instance.client.rpc('available_qty', params: {
    'p_listing': q.listingId,
    'p_vtype': q.vehicleType,
    'p_start': q.start.toIso8601String(),
    'p_end': q.end.toIso8601String(),
  });
  return (res as num?)?.toInt() ?? 0;
});
