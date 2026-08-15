import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateProvider (moved to legacy in Riverpod 3)
import '../../../owner/presentation/controllers/listings_controller.dart';
import '../../../parking/data/places_repository.dart';
import '../../data/ai_recommendation_service.dart';
import '../../data/models/listing_filter.dart';
import '../controllers/rider_bookings_provider.dart';
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
  final FocusNode _searchFocus = FocusNode();

  /// Debounce so a fast typist doesn't fire one Places call per keystroke.
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;

  /// Pin for the place the rider searched for, kept apart from the parking
  /// markers so "where I looked" never reads as "a spot you can book".
  LatLng? _searchedPoint;
  String _searchedLabel = '';

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
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // -------------------- Location --------------------

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
    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      ref.read(riderPositionProvider.notifier).state = position;
      final controller = await _controller.future;
      await controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 16.0,
        ),
      ));
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.locationNotFound)));
      }
    }
  }

  // -------------------- Search --------------------

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetch(value));
  }

  Future<void> _fetch(String value) async {
    final pos = ref.read(riderPositionProvider);
    final results = await ref.read(placesRepositoryProvider).autocomplete(
          value,
          lat: pos?.latitude,
          lng: pos?.longitude,
        );
    // A slower earlier request must not overwrite a newer query's results.
    if (!mounted || _searchController.text.trim() != value.trim()) return;
    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  Future<void> _choose(PlaceSuggestion s) async {
    _searchFocus.unfocus();
    setState(() {
      _suggestions = const [];
      _searching = true;
    });

    final loc = await ref.read(placesRepositoryProvider).resolve(s);
    if (!mounted) return;
    setState(() => _searching = false);

    if (loc == null) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.locationNotFound)));
      return;
    }

    _searchController.text = s.title;
    setState(() {
      _searchedPoint = LatLng(loc.lat, loc.lng);
      _searchedLabel = loc.address.isNotEmpty ? loc.address : s.title;
    });

    final controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _searchedPoint!, zoom: 15.5),
    ));
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _suggestions = const [];
      _searching = false;
      _searchedPoint = null;
      _searchedLabel = '';
    });
  }

  Future<void> _openFilters() async {
    final current = ref.read(listingFilterProvider);
    final updated = await showFilterSheet(context, current);
    if (updated != null) {
      ref.read(listingFilterProvider.notifier).state = updated;
    }
  }

  // -------------------- Markers --------------------

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
    final markers = <Marker>{};

    // Parking spots: violet when bookable, rose + faded when full.
    for (final listing in listings) {
      final available = listing.availableSlots > 0;
      markers.add(Marker(
        markerId: MarkerId('spot_${listing.id ?? listing.hashCode}'),
        position: LatLng(listing.latitude, listing.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          available ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueRose,
        ),
        alpha: available ? 1.0 : 0.5,
        infoWindow: InfoWindow(
          title: listing.title,
          snippet: available
              ? '৳${listing.hourlyRate?.toInt() ?? 0}/hr · ${listing.availableSlots} ${l10n.freeSpots}'
              : l10n.fullNoSlots,
          onTap: () => context.push('/rider/explore/details', extra: listing),
        ),
      ));
    }

    // Searched destination: azure, so it can never be mistaken for a spot.
    final point = _searchedPoint;
    if (point != null) {
      markers.add(Marker(
        markerId: const MarkerId('searched'),
        position: point,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: _searchedLabel),
      ));
    }

    // Rider: green dot marker in addition to the platform blue dot, because the
    // blue dot disappears the moment the OS stops publishing a fix.
    final pos = ref.watch(riderPositionProvider);
    if (pos != null) {
      markers.add(Marker(
        markerId: const MarkerId('me'),
        position: LatLng(pos.latitude, pos.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        zIndexInt: 2,
        infoWindow: InfoWindow(title: l10n.yourLocation),
      ));
    }

    return markers;
  }

  // -------------------- AI sheet --------------------

  void _showAskAIBottomSheet(List<ListingModel> listings) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
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
                  FilledButton(
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
                                .catchError(
                                    (_) => const RiderHistoryProfile());

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
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: isAiLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
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
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pick != null)
                              Text(
                                '${pick!.listing.title} · ৳${pick!.listing.hourlyRate?.toInt() ?? 0}/hr · ${pick!.distanceKm.toStringAsFixed(1)} km',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme
                                        .colorScheme.onPrimaryContainer),
                              ),
                            const SizedBox(height: 4),
                            Text(aiResponse,
                                style: TextStyle(
                                    fontSize: 15,
                                    color: theme
                                        .colorScheme.onPrimaryContainer)),
                            if (pick != null) ...[
                              const SizedBox(height: 8),
                              Text(l10n.tapToView,
                                  style: TextStyle(
                                      color: theme.colorScheme.primary,
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

  // -------------------- Build --------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
            // Tapping the map dismisses the suggestion list.
            onTap: (_) => _searchFocus.unfocus(),
            onMapCreated: (controller) {
              if (!_controller.isCompleted) _controller.complete(controller);
            },
          ),

          // Floating search bar + suggestions + filter
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  elevation: 4,
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(30),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onQueryChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.whereToPark,
                      prefixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : Icon(Icons.search,
                              color: theme.colorScheme.primary),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              tooltip: l10n.close,
                              icon: Icon(Icons.close,
                                  size: 20, color: theme.hintColor),
                              onPressed: _clearSearch,
                            ),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.filter_list,
                                  color: filter.isActive
                                      ? theme.colorScheme.primary
                                      : theme.hintColor,
                                ),
                                onPressed: _openFilters,
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
                                            color:
                                                theme.colorScheme.onPrimary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Material(
                    elevation: 4,
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in _suggestions)
                          ListTile(
                            dense: true,
                            leading: Icon(Icons.place_outlined,
                                color: theme.colorScheme.primary),
                            title: Text(s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: s.subtitle.isEmpty
                                ? null
                                : Text(s.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                            onTap: () => _choose(s),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Result count / loading / empty hint
          if (_suggestions.isEmpty)
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

          // Browse-as-list button
          Positioned(
            bottom: 168,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'browseList',
              tooltip: l10n.browseList,
              backgroundColor: theme.colorScheme.surfaceContainerLow,
              foregroundColor: theme.colorScheme.primary,
              onPressed: () => context.push('/rider/explore/listings'),
              child: const Icon(Icons.view_list),
            ),
          ),

          // Ask AI button
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'askAI',
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              onPressed: () => _showAskAIBottomSheet(visible),
              child: const Icon(Icons.auto_awesome),
            ),
          ),

          // Current location button
          Positioned(
            bottom: 32,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'currentLocation',
              tooltip: l10n.useMyLocation,
              backgroundColor: theme.colorScheme.surfaceContainerLow,
              foregroundColor: theme.colorScheme.primary,
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Active Session floating banner
          Consumer(
            builder: (context, ref, _) {
              final riderBookings = ref.watch(riderBookingsProvider).value ?? [];
              const liveStatuses = {'Pending', 'Confirmed', 'Active'};
              final liveBooking = riderBookings
                  .where((b) =>
                      liveStatuses.contains(b.status) &&
                      b.endTime.isAfter(DateTime.now()))
                  .firstOrNull;
              if (liveBooking == null) return const SizedBox.shrink();

              return Positioned(
                bottom: 32,
                left: 16,
                right: 88,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.green.shade700,
                  child: InkWell(
                    onTap: () => context.push('/active_session'),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.activeSession,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  liveBooking.listing?.title ?? l10n.parkingSpot,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              color: Colors.white70, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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
    final theme = Theme.of(context);
    String text;
    if (async.isLoading && !async.hasValue) {
      text = loadingText;
    } else if (async.hasError) {
      text = errorText;
    } else {
      text = '$spotsText${filterActive ? filteredSuffix : ''}';
    }
    return Material(
      elevation: 2,
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(text,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
