import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Aggregate rating for one listing (from `listing_rating_summary` view).
class RatingSummary {
  final double avgRating;
  final int reviewCount;

  const RatingSummary({required this.avgRating, required this.reviewCount});

  static const empty = RatingSummary(avgRating: 0, reviewCount: 0);
}

/// A single rider review row joined with the reviewer's profile.
class ReviewModel {
  final String id;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final String? reviewerName;
  final String? reviewerAvatar;

  ReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    this.createdAt,
    this.reviewerName,
    this.reviewerAvatar,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ReviewModel(
      id: json['id'] as String,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      reviewerName: profile?['full_name'] as String?,
      reviewerAvatar: profile?['avatar_url'] as String?,
    );
  }
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(Supabase.instance.client);
});

class ReviewsRepository {
  final SupabaseClient _client;
  ReviewsRepository(this._client);

  /// Per-listing avg rating + count. Empty summary if no reviews yet.
  Future<RatingSummary> getRatingSummary(String listingId) async {
    final rows = await _client
        .from('listing_rating_summary')
        .select('avg_rating, review_count')
        .eq('listing_id', listingId)
        .limit(1);
    if ((rows as List).isEmpty) return RatingSummary.empty;
    final r = rows.first;
    return RatingSummary(
      avgRating: (r['avg_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (r['review_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Rating summaries for many listings at once (for map/filters/AI scoring).
  /// Returns listingId -> RatingSummary. Missing ids default to empty.
  Future<Map<String, RatingSummary>> getRatingSummaries(
      List<String> listingIds) async {
    if (listingIds.isEmpty) return {};
    final rows = await _client
        .from('listing_rating_summary')
        .select('listing_id, avg_rating, review_count')
        .inFilter('listing_id', listingIds);
    final map = <String, RatingSummary>{};
    for (final r in rows as List) {
      map[r['listing_id'] as String] = RatingSummary(
        avgRating: (r['avg_rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (r['review_count'] as num?)?.toInt() ?? 0,
      );
    }
    return map;
  }

  /// Rider reviews for a listing, newest first, with reviewer profile.
  Future<List<ReviewModel>> getListingReviews(String listingId) async {
    final rows = await _client
        .from('reviews')
        .select('id, rating, comment, created_at, profiles!reviews_reviewer_id_fkey(full_name, avatar_url)')
        .eq('listing_id', listingId)
        .neq('reviewer_role', 'owner')
        .order('created_at', ascending: false)
        .limit(20);
    return (rows as List).map((e) => ReviewModel.fromJson(e)).toList();
  }

  /// Submit a review for a completed booking. Server validates the caller
  /// owns that side (rider or owner) and that the booking is Completed.
  /// Returns the server message; throws on failure so the UI can surface it.
  Future<String> submitReview({
    required String bookingId,
    required int rating,
    String? comment,
    bool asOwner = false,
  }) async {
    final res = await _client.rpc('submit_review', params: {
      'p_booking': bookingId,
      'p_rating': rating,
      'p_comment': comment,
      'p_as_owner': asOwner,
    });
    final map = (res as Map).cast<String, dynamic>();
    if (map['ok'] != true) {
      throw Exception(map['msg'] ?? 'Could not submit review');
    }
    return map['msg'] as String? ?? 'Thanks for your review';
  }

  /// Booking ids the current user has already reviewed for the given side.
  /// Used to hide the "Rate" button on already-reviewed bookings.
  Future<Set<String>> getReviewedBookingIds({bool asOwner = false}) async {
    final rows =
        await _client.rpc('my_reviewed_bookings', params: {'p_as_owner': asOwner});
    return (rows as List).map((e) => e.toString()).toSet();
  }
}

/// Booking ids the signed-in rider (or owner) has already reviewed.
final reviewedBookingIdsProvider =
    FutureProvider.family.autoDispose<Set<String>, bool>((ref, asOwner) {
  return ref.watch(reviewsRepositoryProvider).getReviewedBookingIds(asOwner: asOwner);
});
