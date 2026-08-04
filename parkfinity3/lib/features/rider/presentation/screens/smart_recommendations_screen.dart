import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/ai_recommendation_service.dart';
import '../controllers/rider_history_provider.dart';
import '../../../owner/presentation/controllers/listings_controller.dart';
import 'explore_map_screen.dart'; // riderPositionProvider, listingFilterProvider
import '../../../../l10n/generated/app_localizations.dart';

/// Ranked recommendations for the signed-in rider, using the hybrid engine
/// (local scoring + Groq explanation on the top pick). Respects the active
/// discovery filter and the rider's real GPS.
final smartRecommendationsProvider =
    FutureProvider.autoDispose<List<ScoredListing>>((ref) async {
  final listings = await ref.watch(allActiveListingsProvider.future);
  if (listings.isEmpty) return [];

  final filter = ref.watch(listingFilterProvider);
  final pos = ref.watch(riderPositionProvider);
  final userLat = pos?.latitude ?? 23.8103;
  final userLng = pos?.longitude ?? 90.4125;

  // Apply the same discovery filter used on the map.
  final filtered = filter.apply(listings,
      userLat: pos?.latitude, userLng: pos?.longitude);
  final pool = filtered.isEmpty && !filter.isActive ? listings : filtered;

  final history = await ref
      .watch(riderHistoryProfileProvider.future)
      .catchError((_) => const RiderHistoryProfile());

  return ref.watch(aiRecommendationProvider).recommend(
        listings: pool,
        userLat: userLat,
        userLng: userLng,
        history: history,
        explainTop: true,
      );
});

class SmartRecommendationsScreen extends ConsumerWidget {
  const SmartRecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recsAsync = ref.watch(smartRecommendationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.smartRecommendations),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: recsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('${l10n.couldNotLoadRecommendations}\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (recs) {
          if (recs.isEmpty) {
            return Center(
                child: Text(l10n.noMatchingSpots,
                    textAlign: TextAlign.center));
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(smartRecommendationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recs.length,
              itemBuilder: (_, i) => _RecCard(
                scored: recs[i],
                rank: i + 1,
                isTop: i == 0,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecCard extends StatelessWidget {
  final ScoredListing scored;
  final int rank;
  final bool isTop;
  const _RecCard(
      {required this.scored, required this.rank, required this.isTop});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final l = scored.listing;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isTop ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isTop
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/rider/explore/details', extra: l),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTop)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('⭐ ${l10n.topPick}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text('$rank',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.title,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(l.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Theme.of(context).hintColor, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _pill(context, Icons.near_me,
                      '${scored.distanceKm.toStringAsFixed(1)} km'),
                  _pill(context, Icons.attach_money,
                      '৳${l.hourlyRate?.toInt() ?? 0}/hr'),
                  if (scored.rating > 0)
                    _pill(context, Icons.star, scored.rating.toStringAsFixed(1)),
                  _pill(context, Icons.event_available,
                      '${l.availableSlots} ${l10n.freeSpots}'),
                ],
              ),
              if (isTop && scored.explanation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 18,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(scored.explanation!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
