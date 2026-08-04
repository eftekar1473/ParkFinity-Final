import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One autocomplete row. [placeId] is null when the suggestion came from the
/// on-device geocoder fallback — those already carry coordinates.
class PlaceSuggestion {
  final String? placeId;
  final String title;
  final String subtitle;
  final double? lat;
  final double? lng;

  const PlaceSuggestion({
    this.placeId,
    required this.title,
    this.subtitle = '',
    this.lat,
    this.lng,
  });
}

/// Resolved coordinates for a chosen suggestion.
class PlaceLocation {
  final double lat;
  final double lng;
  final String address;
  const PlaceLocation(this.lat, this.lng, this.address);
}

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository(Supabase.instance.client);
});

/// Place search that goes through the `places-search` Edge Function, so the
/// Google key stays server-side. Falls back to the on-device geocoder whenever
/// the function is unavailable or returns nothing — the rider still gets a
/// usable search box on a plane, on a bad network, or with the key unset.
class PlacesRepository {
  final SupabaseClient _client;
  PlacesRepository(this._client);

  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    double? lat,
    double? lng,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    try {
      final res = await _client.functions.invoke('places-search', body: {
        'action': 'autocomplete',
        'query': q,
        'lat': ?lat,
        'lng': ?lng,
      });
      final data = res.data;
      if (res.status < 400 && data is Map && data['predictions'] is List) {
        final list = (data['predictions'] as List)
            .map((e) => PlaceSuggestion(
                  placeId: e['id'] as String?,
                  title: (e['title'] ?? '').toString(),
                  subtitle: (e['subtitle'] ?? '').toString(),
                ))
            .where((s) => s.title.isNotEmpty)
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {
      // Fall through to the device geocoder.
    }

    return _deviceFallback(q);
  }

  /// On-device geocoding produces coordinates but no pretty two-line label, so
  /// the query itself is used as the title.
  Future<List<PlaceSuggestion>> _deviceFallback(String q) async {
    try {
      final locations = await Geocoding().locationFromAddress(q);
      return locations
          .take(5)
          .map((l) => PlaceSuggestion(
                title: q,
                subtitle:
                    '${l.latitude.toStringAsFixed(4)}, ${l.longitude.toStringAsFixed(4)}',
                lat: l.latitude,
                lng: l.longitude,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Coordinates for a suggestion. Already-resolved fallback rows skip the call.
  Future<PlaceLocation?> resolve(PlaceSuggestion s) async {
    if (s.lat != null && s.lng != null) {
      return PlaceLocation(s.lat!, s.lng!, s.title);
    }
    if (s.placeId == null) return null;

    try {
      final res = await _client.functions.invoke('places-search', body: {
        'action': 'details',
        'place_id': s.placeId,
      });
      final data = res.data;
      if (res.status < 400 && data is Map && data['lat'] != null) {
        return PlaceLocation(
          (data['lat'] as num).toDouble(),
          (data['lng'] as num).toDouble(),
          (data['address'] ?? s.title).toString(),
        );
      }
    } catch (_) {
      // Fall through.
    }

    // Last resort: geocode the label we showed the rider.
    final byName = await _deviceFallback('${s.title} ${s.subtitle}'.trim());
    if (byName.isNotEmpty) {
      return PlaceLocation(byName.first.lat!, byName.first.lng!, s.title);
    }
    return null;
  }
}
