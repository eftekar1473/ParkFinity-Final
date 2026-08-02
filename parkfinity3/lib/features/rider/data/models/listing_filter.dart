import 'dart:math' as math;
import '../../../owner/data/models/listing_model.dart';

/// Client-side discovery filter. Applied over already-loaded listings — no
/// extra queries, so it's free and instant. Combine with live availability.
class ListingFilter {
  /// Max distance from rider GPS in km (null = any distance).
  final double? maxDistanceKm;

  /// Max hourly rate in BDT (null = any price).
  final double? maxHourlyRate;

  /// Minimum average rating 0..5 (0 = any).
  final double minRating;

  /// Vehicle type that must have a free slot (null = any type).
  final String? vehicleType;

  final bool requireSecurity;
  final bool requireCctv;
  final bool requireCovered;
  final bool requireEvCharging;

  /// Only show spots that currently have at least one free slot.
  final bool onlyAvailable;

  const ListingFilter({
    this.maxDistanceKm,
    this.maxHourlyRate,
    this.minRating = 0,
    this.vehicleType,
    this.requireSecurity = false,
    this.requireCctv = false,
    this.requireCovered = false,
    this.requireEvCharging = false,
    this.onlyAvailable = true,
  });

  static const none = ListingFilter();

  bool get isActive =>
      maxDistanceKm != null ||
      maxHourlyRate != null ||
      minRating > 0 ||
      vehicleType != null ||
      requireSecurity ||
      requireCctv ||
      requireCovered ||
      requireEvCharging;

  /// Count of active constraints (for the filter badge).
  int get activeCount =>
      (maxDistanceKm != null ? 1 : 0) +
      (maxHourlyRate != null ? 1 : 0) +
      (minRating > 0 ? 1 : 0) +
      (vehicleType != null ? 1 : 0) +
      (requireSecurity ? 1 : 0) +
      (requireCctv ? 1 : 0) +
      (requireCovered ? 1 : 0) +
      (requireEvCharging ? 1 : 0);

  ListingFilter copyWith({
    double? maxDistanceKm,
    double? maxHourlyRate,
    double? minRating,
    String? vehicleType,
    bool? requireSecurity,
    bool? requireCctv,
    bool? requireCovered,
    bool? requireEvCharging,
    bool? onlyAvailable,
    bool clearDistance = false,
    bool clearPrice = false,
    bool clearVehicleType = false,
  }) {
    return ListingFilter(
      maxDistanceKm: clearDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
      maxHourlyRate: clearPrice ? null : (maxHourlyRate ?? this.maxHourlyRate),
      minRating: minRating ?? this.minRating,
      vehicleType:
          clearVehicleType ? null : (vehicleType ?? this.vehicleType),
      requireSecurity: requireSecurity ?? this.requireSecurity,
      requireCctv: requireCctv ?? this.requireCctv,
      requireCovered: requireCovered ?? this.requireCovered,
      requireEvCharging: requireEvCharging ?? this.requireEvCharging,
      onlyAvailable: onlyAvailable ?? this.onlyAvailable,
    );
  }

  /// Apply this filter to a list. [ratings] maps listingId -> avg rating.
  /// [userLat]/[userLng] required only when a distance constraint is set.
  List<ListingModel> apply(
    List<ListingModel> listings, {
    Map<String, double> ratings = const {},
    double? userLat,
    double? userLng,
  }) {
    return listings.where((l) {
      // Availability: has at least one free slot overall.
      if (onlyAvailable && l.availableSlots <= 0) return false;

      // Vehicle type: must have a free slot for that type.
      if (vehicleType != null) {
        final free = l.slotAvailable[vehicleType] ?? 0;
        if (free <= 0) return false;
      }

      // Price.
      if (maxHourlyRate != null) {
        final rate = l.hourlyRate;
        if (rate == null || rate > maxHourlyRate!) return false;
      }

      // Rating.
      if (minRating > 0) {
        final r = ratings[l.id] ?? 0;
        if (r < minRating) return false;
      }

      // Amenities.
      if (requireSecurity && !l.hasSecurity) return false;
      if (requireCctv && !l.hasCctv) return false;
      if (requireCovered && !l.isCovered) return false;
      if (requireEvCharging && !l.hasEvCharging) return false;

      // Distance (Haversine from rider GPS).
      if (maxDistanceKm != null && userLat != null && userLng != null) {
        final d = _haversineKm(userLat, userLng, l.latitude, l.longitude);
        if (d > maxDistanceKm!) return false;
      }

      return true;
    }).toList();
  }

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
