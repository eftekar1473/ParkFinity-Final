import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../owner/data/models/listing_model.dart';
import '../../../owner/presentation/controllers/listings_controller.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/repositories/reviews_repository.dart';
import '../../data/models/listing_filter.dart';
import '../widgets/filter_sheet.dart';
import 'explore_map_screen.dart'; // listingFilterProvider, riderPositionProvider

/// Rating map for the listing list. Mirrors the map screen's ratings source so
/// the same star values back both the list and the distance/rating filter.
final _listingsRatingsProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final listings = ref.watch(activeListingsStreamProvider).value ?? [];
  final ids = listings.map((l) => l.id).whereType<String>().toList();
  if (ids.isEmpty) return {};
  final summaries =
      await ref.watch(reviewsRepositoryProvider).getRatingSummaries(ids);
  return {for (final e in summaries.entries) e.key: e.value.avgRating};
});

/// A flat, scrollable list of every active parking spot, with the same filter
/// sheet the map uses. Riders who prefer a browsable list over the map get one
/// here; tapping a row opens the existing listing details screen.
class ListingsScreen extends ConsumerWidget {
  const ListingsScreen({super.key});

  Future<void> _openFilters(BuildContext context, WidgetRef ref) async {
    final current = ref.read(listingFilterProvider);
    final updated = await showFilterSheet(context, current);
    if (updated != null) {
      ref.read(listingFilterProvider.notifier).state = updated;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final listingsAsync = ref.watch(activeListingsStreamProvider);
    final ratings = ref.watch(_listingsRatingsProvider).value ?? {};
    final filter = ref.watch(listingFilterProvider);
    final pos = ref.watch(riderPositionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.allListings),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.filter_list,
                    color: filter.isActive
                        ? theme.colorScheme.primary
                        : null),
                onPressed: () => _openFilters(context, ref),
              ),
              if (filter.isActive)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle),
                    child: Text('${filter.activeCount}',
                        style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: listingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.error}: $e')),
        data: (all) {
          final visible = filter.apply(
            all,
            ratings: ratings,
            userLat: pos?.latitude,
            userLng: pos?.longitude,
          );
          if (visible.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_parking_outlined,
                        size: 56, color: theme.hintColor),
                    const SizedBox(height: 12),
                    Text(
                      filter.isActive ? l10n.noResults : l10n.noNotificationsYet,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.hintColor),
                    ),
                    if (filter.isActive) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(listingFilterProvider.notifier)
                            .state = ListingFilter.none,
                        child: Text(l10n.reset),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ListingCard(
              listing: visible[i],
              rating: ratings[visible[i].id],
              onTap: () => context.push('/rider/explore/details',
                  extra: visible[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final ListingModel listing;
  final double? rating;
  final VoidCallback onTap;
  const _ListingCard(
      {required this.listing, required this.rating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final available = listing.availableSlots > 0;
    final photo = listing.photos.isNotEmpty ? listing.photos.first : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: photo != null
                    ? Image.network(photo,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(theme))
                    : _placeholder(theme),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(listing.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: theme.hintColor, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (rating != null && rating! > 0) ...[
                          const Icon(Icons.star,
                              size: 15, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(rating!.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 10),
                        ],
                        Icon(Icons.event_available,
                            size: 15,
                            color: available
                                ? Colors.green
                                : theme.colorScheme.error),
                        const SizedBox(width: 2),
                        Text(
                          available
                              ? '${listing.availableSlots} ${l10n.freeSpots}'
                              : l10n.fullNoSlots,
                          style: TextStyle(
                              fontSize: 13,
                              color: available
                                  ? Colors.green
                                  : theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('৳${listing.hourlyRate?.toInt() ?? 0}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.colorScheme.primary)),
                  Text('/hr',
                      style:
                          TextStyle(fontSize: 12, color: theme.hintColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
        width: 72,
        height: 72,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        child: Icon(Icons.local_parking, color: theme.colorScheme.primary),
      );
}
