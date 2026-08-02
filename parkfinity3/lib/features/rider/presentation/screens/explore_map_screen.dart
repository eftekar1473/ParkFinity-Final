import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateProvider (moved to legacy in Riverpod 3)
import '../../../owner/presentation/controllers/listings_controller.dart';
import '../../data/ai_recommendation_service.dart';
import '../../data/models/listing_filter.dart';
import '../controllers/rider_history_provider.dart';
import '../widgets/filter_sheet.dart';
import '../../../owner/data/models/listing_model.dart';
import '../../data/repositories/reviews_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Rider's current GPS position (null until resolved). Shared with the AI
/// sheet and distance filter so both use the real location, not a constant.
final riderPositionProvider = StateProvider<Position?>((ref) => null);

/// Active discovery filter for the explore map.
final listingFilterProvider =
    StateProvider<ListingFilter>((ref) => ListingFilter.none);

/// Rating summaries for currently-loaded listings (for filter + marker use).
final _ratingsProvider = FutureProvider<Map<String, double>>((ref) async {
  final listings = ref.watch(activeListingsStreamProvider).value ?? [];
  final ids = listings.map((l) => l.id).whereType<String>().toList();
  if (ids.isEmpty) return {};
  final summaries =
      await ref.watch(reviewsRepositoryProvider).getRatingSummaries(ids);
  return {for (final e in summaries.entries) e.key: e.value.avgRating};
});

class ExploreMapScreen extends ConsumerStatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  ConsumerState<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends ConsumerState<ExploreMapScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  final TextEditingController _searchController = TextEditingController();

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(23.8103, 90.4125), // Dhaka fallback until GPS resolves
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      await _goToCurrentLocation();
    } catch (_) {
      // Location unavailable — map stays on Dhaka fallback.
    }
  }

  Future<void> _goToCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition();
    ref.read(riderPositionProvider.notifier).state = position;
    final controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 16.0,
      ),
    ));
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final locations = await Geocoding().locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final controller = await _controller.future;
        await controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(location.latitude, location.longitude),
            zoom: 15.0,
          ),
        ));
      }
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.locationNotFound)));
      }
    }
  }

  Future<void> _openFilters() async {
    final current = ref.read(listingFilterProvider);
    final updated = await showFilterSheet(context, current);
    if (updated != null) {
      ref.read(listingFilterProvider.notifier).state = updated;
    }
  }

  /// Listings after applying the active filter (+ availability).
  List<ListingModel> _visibleListings(
      List<ListingModel> all, Map<String, double> ratings) {
    final filter = ref.watch(listingFilterProvider);
    final pos = ref.watch(riderPositionProvider);
    return filter.apply(
      all,
      ratings: ratings,
      userLat: pos?.latitude,
      userLng: pos?.longitude,
    );
  }

  Set<Marker> _buildMarkers(List<ListingModel> listings, AppLocalizations l10n) {
    return listings.map((listing) {
      final available = listing.availableSlots > 0;
      return Marker(
        markerId: MarkerId(listing.id ?? listing.hashCode.toString()),
        position: LatLng(listing.latitude, listing.longitude),
        // Greyed marker when full so riders can still see the spot exists.
        icon: BitmapDescriptor.defaultMarkerWithHue(
          available
              ? BitmapDescriptor.hueViolet
              : BitmapDescriptor.hueRose,
        ),
        alpha: available ? 1.0 : 0.5,
        infoWindow: InfoWindow(
          title: listing.title,
          snippet: available
              ? '৳${listing.hourlyRate?.toInt() ?? 0}/hr · ${listing.availableSlots} ${l10n.freeSpots}'
              : l10n.fullNoSlots,
          onTap: () =>
              context.push('/rider/explore/details', extra: listing),
        ),
      );
    }).toSet();
  }

  void _showAskAIBottomSheet(List<ListingModel> listings) {
    final l10n = AppLocalizations.of(context);
    final aiController = TextEditingController();
    bool isAiLoading = false;
    String aiResponse = '';
    ScoredListing? pick;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.askParkfinityAi,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple)),
                  const SizedBox(height: 8),
                  Text(l10n.aiPromptHint),
                  const SizedBox(height: 16),
                  TextField(
                    controller: aiController,
                    decoration: InputDecoration(
                      hintText: l10n.yourPreference,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isAiLoading
                        ? null
                        : () async {
                            setModalState(() {
                              isAiLoading = true;
                              aiResponse = '';
                              pick = null;
                            });

                            final aiService =
                                ref.read(aiRecommendationProvider);
                            // Real GPS if we have it; Dhaka centre as fallback.
                            final pos = ref.read(riderPositionProvider);
                            final history = await ref
                                .read(riderHistoryProfileProvider.future)
                                .catchError((_) =>
                                    const RiderHistoryProfile());

                            final best = await aiService.getBest(
                              listings: listings,
                              userLat: pos?.latitude ?? 23.8103,
                              userLng: pos?.longitude ?? 90.4125,
                              history: history,
                              userPreferences: aiController.text,
                            );

                            setModalState(() {
                              isAiLoading = false;
                              pick = best;
                              if (best != null) {
                                aiResponse = best.explanation ??
                                    l10n.aiRecommend(best.listing.title);
                              } else {
                                aiResponse = l10n.aiNoMatch;
                              }
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isAiLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white))
                        : Text(l10n.askAi),
                  ),
                  if (aiResponse.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: pick == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              context.push('/rider/explore/details',
                                  extra: pick!.listing);
                            },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.deepPurple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pick != null)
                              Text(
                                '${pick!.listing.title} · ৳${pick!.listing.hourlyRate?.toInt() ?? 0}/hr · ${pick!.distanceKm.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            const SizedBox(height: 4),
                            Text(aiResponse,
                                style: const TextStyle(fontSize: 15)),
                            if (pick != null) ...[
                              const SizedBox(height: 8),
                              Text(l10n.tapToView,
                                  style: const TextStyle(
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/rider/explore/recommendations');
                    },
                    icon: const Icon(Icons.list_alt),
                    label: Text(l10n.seeAllRecommendations),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final listingsAsync = ref.watch(activeListingsStreamProvider);
    final ratings = ref.watch(_ratingsProvider).value ?? {};
    final filter = ref.watch(listingFilterProvider);

    final all = listingsAsync.value ?? [];
    final visible = _visibleListings(all, ratings);
    final markers = _buildMarkers(visible, l10n);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: markers,
            onMapCreated: (controller) => _controller.complete(controller),
          ),

          // Floating Search Bar + filter
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: _searchPlace,
                decoration: InputDecoration(
                  hintText: l10n.whereToPark,
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.deepPurple),
                  suffixIcon: Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.filter_list,
                          color: filter.isActive
                              ? Colors.deepPurple
                              : Colors.grey.shade600,
                        ),
                        onPressed: _openFilters,
                      ),
                      if (filter.isActive)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.deepPurple,
                                shape: BoxShape.circle),
                            child: Text('${filter.activeCount}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // Result count / loading / empty hint
          Positioned(
            top: 108,
            left: 16,
            child: _StatusChip(
              async: listingsAsync,
              visibleCount: visible.length,
              filterActive: filter.isActive,
              loadingText: l10n.loadingSpots,
              errorText: l10n.couldNotLoadSpots,
              spotsText: l10n.spotsFound(visible.length),
              filteredSuffix: l10n.filteredSuffix,
            ),
          ),

          // Ask AI button
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'askAI',
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.auto_awesome, color: Colors.white),
              onPressed: () => _showAskAIBottomSheet(visible),
            ),
          ),

          // Current location button
          Positioned(
            bottom: 32,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'currentLocation',
              backgroundColor: Colors.white,
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location, color: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AsyncValue async;
  final int visibleCount;
  final bool filterActive;
  final String loadingText;
  final String errorText;
  final String spotsText;
  final String filteredSuffix;
  const _StatusChip({
    required this.async,
    required this.visibleCount,
    required this.filterActive,
    required this.loadingText,
    required this.errorText,
    required this.spotsText,
    required this.filteredSuffix,
  });

  @override
  Widget build(BuildContext context) {
    String text;
    if (async.isLoading && !async.hasValue) {
      text = loadingText;
    } else if (async.hasError) {
      text = errorText;
    } else {
      text = '$spotsText${filterActive ? filteredSuffix : ''}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
