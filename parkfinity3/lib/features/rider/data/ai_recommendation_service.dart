import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../owner/data/models/listing_model.dart';
import 'repositories/reviews_repository.dart';

/// A listing plus its computed recommendation score and (optional) AI blurb.
class ScoredListing {
  final ListingModel listing;
  final double score; // 0..1 composite
  final double distanceKm;
  final double rating;
  final String? explanation; // Groq one-liner, filled for top pick(s)

  ScoredListing({
    required this.listing,
    required this.score,
    required this.distanceKm,
    required this.rating,
    this.explanation,
  });

  ScoredListing copyWith({String? explanation}) => ScoredListing(
        listing: listing,
        score: score,
        distanceKm: distanceKm,
        rating: rating,
        explanation: explanation ?? this.explanation,
      );
}

/// Signals distilled from a rider's booking history to bias ranking toward
/// spots similar to what they've booked before.
class RiderHistoryProfile {
  final Set<String> ownerIds; // previously-booked owners
  final double? avgHourlyPrice; // typical price band
  final int bookingCount;

  const RiderHistoryProfile({
    this.ownerIds = const {},
    this.avgHourlyPrice,
    this.bookingCount = 0,
  });

  bool get isEmpty => bookingCount == 0;
}

final aiRecommendationProvider = Provider<AiRecommendationService>((ref) {
  return AiRecommendationService(ref.watch(reviewsRepositoryProvider));
});

/// Hybrid recommender: a deterministic local scoring engine ranks spots
/// (free, instant), and Groq is used ONLY to phrase a one-line "why this
/// spot" explanation for the top pick(s) — never for ranking.
class AiRecommendationService {
  final ReviewsRepository _reviews;
  AiRecommendationService(this._reviews);

  final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
  final String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  // Scoring weights (sum ~= 1.0). Distance & price dominate, then rating,
  // then security amenities, then history affinity.
  static const double _wDistance = 0.35;
  static const double _wPrice = 0.25;
  static const double _wRating = 0.20;
  static const double _wSecurity = 0.10;
  static const double _wHistory = 0.10;

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _deg2rad(double d) => d * math.pi / 180.0;

  /// Rank listings for a rider. Pure local math — deterministic and free.
  /// [ratings] maps listingId -> avg rating (0 if unknown).
  List<ScoredListing> rankListings({
    required List<ListingModel> listings,
    required double userLat,
    required double userLng,
    required Map<String, double> ratings,
    RiderHistoryProfile history = const RiderHistoryProfile(),
  }) {
    if (listings.isEmpty) return [];

    // Pre-compute per-listing raw features.
    final distances = <double>[];
    final prices = <double>[];
    for (final l in listings) {
      distances.add(_haversineKm(userLat, userLng, l.latitude, l.longitude));
      prices.add(l.hourlyRate ?? _fallbackHourly(l));
    }

    final maxDist = distances.reduce(math.max).clamp(0.0001, double.infinity);
    final maxPrice = prices.reduce(math.max).clamp(0.0001, double.infinity);

    final scored = <ScoredListing>[];
    for (var i = 0; i < listings.length; i++) {
      final l = listings[i];
      final dist = distances[i];
      final price = prices[i];
      final rating = ratings[l.id] ?? 0.0;

      // Normalise each feature to 0..1 (higher = better).
      final nDistance = 1.0 - (dist / maxDist); // closer -> 1
      final nPrice = 1.0 - (price / maxPrice); // cheaper -> 1
      final nRating = rating / 5.0; // 0..1
      final securityFlags = (l.hasSecurity ? 1 : 0) +
          (l.hasCctv ? 1 : 0) +
          (l.isCovered ? 1 : 0);
      final nSecurity = securityFlags / 3.0;
      final nHistory = _historyMatch(l, price, history);

      final score = _wDistance * nDistance +
          _wPrice * nPrice +
          _wRating * nRating +
          _wSecurity * nSecurity +
          _wHistory * nHistory;

      scored.add(ScoredListing(
        listing: l,
        score: score,
        distanceKm: dist,
        rating: rating,
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// 0..1 affinity: booked this owner before, or price near the rider's band.
  double _historyMatch(
      ListingModel l, double price, RiderHistoryProfile h) {
    if (h.isEmpty) return 0.0;
    double m = 0.0;
    if (h.ownerIds.contains(l.ownerId)) m += 0.6;
    if (h.avgHourlyPrice != null && h.avgHourlyPrice! > 0) {
      final diff = (price - h.avgHourlyPrice!).abs() / h.avgHourlyPrice!;
      m += 0.4 * (1.0 - diff.clamp(0.0, 1.0)); // closer to usual band -> up to 0.4
    }
    return m.clamp(0.0, 1.0);
  }

  /// Rough hourly estimate when a listing only set a daily/weekly rate.
  double _fallbackHourly(ListingModel l) {
    if (l.dailyRate != null) return l.dailyRate! / 12.0;
    if (l.weeklyRate != null) return l.weeklyRate! / (7 * 12);
    if (l.monthlyRate != null) return l.monthlyRate! / (30 * 12);
    return 50.0; // neutral default (BDT/hr)
  }

  /// Full pipeline: fetch ratings, score, and (optionally) attach a Groq
  /// explanation to the top pick. Returns the ranked list (top first).
  Future<List<ScoredListing>> recommend({
    required List<ListingModel> listings,
    required double userLat,
    required double userLng,
    RiderHistoryProfile history = const RiderHistoryProfile(),
    String userPreferences = '',
    bool explainTop = true,
  }) async {
    final ids = listings.map((l) => l.id).whereType<String>().toList();
    final summaries = await _reviews.getRatingSummaries(ids);
    final ratings = <String, double>{
      for (final e in summaries.entries) e.key: e.value.avgRating,
    };

    final ranked = rankListings(
      listings: listings,
      userLat: userLat,
      userLng: userLng,
      ratings: ratings,
      history: history,
    );

    if (ranked.isEmpty || !explainTop) return ranked;

    final explanation = await _explainTopPick(
      top: ranked.first,
      userPreferences: userPreferences,
    );
    if (explanation != null) {
      final updated = [...ranked];
      updated[0] = ranked.first.copyWith(explanation: explanation);
      return updated;
    }
    return ranked;
  }

  /// Single best pick (used by the map "Ask AI" sheet).
  Future<ScoredListing?> getBest({
    required List<ListingModel> listings,
    required double userLat,
    required double userLng,
    RiderHistoryProfile history = const RiderHistoryProfile(),
    String userPreferences = '',
  }) async {
    final ranked = await recommend(
      listings: listings,
      userLat: userLat,
      userLng: userLng,
      history: history,
      userPreferences: userPreferences,
    );
    return ranked.isEmpty ? null : ranked.first;
  }

  /// Groq generates ONLY the natural-language "why this spot" line. If the
  /// call fails, we fall back to a deterministic local sentence — ranking is
  /// never affected.
  Future<String?> _explainTopPick({
    required ScoredListing top,
    required String userPreferences,
  }) async {
    final l = top.listing;
    final amenities = [
      if (l.isCovered) 'covered',
      if (l.hasSecurity) 'on-site guard',
      if (l.hasCctv) 'CCTV',
      if (l.hasEvCharging) 'EV charging',
    ].join(', ');

    if (_apiKey.isEmpty) {
      return _localExplanation(top, amenities);
    }

    try {
      final facts = {
        'title': l.title,
        'hourly_rate': l.hourlyRate,
        'distance_km': double.parse(top.distanceKm.toStringAsFixed(1)),
        'rating': top.rating > 0 ? top.rating : 'new (no reviews yet)',
        'amenities': amenities.isEmpty ? 'none listed' : amenities,
      };
      final prompt = '''
You are ParkFinity's parking assistant. In ONE short, friendly sentence,
explain why this parking spot is a good pick. Do not invent facts; use only
the data below. ${userPreferences.trim().isEmpty ? '' : 'The rider asked for: "$userPreferences".'}

Spot data: ${jsonEncode(facts)}
''';

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'llama-3.1-8b-instant',
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
              'temperature': 0.5,
              'max_tokens': 80,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['choices'][0]['message']['content'].toString().trim();
        return text.isEmpty ? _localExplanation(top, amenities) : text;
      }
      return _localExplanation(top, amenities);
    } catch (_) {
      return _localExplanation(top, amenities);
    }
  }

  String _localExplanation(ScoredListing top, String amenities) {
    final l = top.listing;
    final parts = <String>[
      'Just ${top.distanceKm.toStringAsFixed(1)} km away',
      if (l.hourlyRate != null) 'at ৳${l.hourlyRate!.toInt()}/hr',
      if (top.rating > 0) 'rated ${top.rating.toStringAsFixed(1)}★',
      if (amenities.isNotEmpty) 'with $amenities',
    ];
    return '${parts.join(', ')} — a strong match for you.';
  }
}
