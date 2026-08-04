import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import '../../../owner/data/models/listing_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/repositories/groq_repository.dart';
import '../../data/repositories/reviews_repository.dart';
import '../../../shared/data/profiles_repository.dart';
import '../../../shared/presentation/screens/photo_viewer_screen.dart';
import '../../../../l10n/generated/app_localizations.dart';

class ListingDetailsScreen extends ConsumerStatefulWidget {
  final ListingModel listing;

  const ListingDetailsScreen({super.key, required this.listing});

  @override
  ConsumerState<ListingDetailsScreen> createState() =>
      _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends ConsumerState<ListingDetailsScreen> {
  String? _aiSummary;
  bool _isLoadingSummary = false;
  VideoPlayerController? _videoController;

  final PageController _galleryController = PageController();
  int _photoIndex = 0;

  ListingModel get l => widget.listing;

  @override
  void initState() {
    super.initState();
    _loadReviewsAndSummary();
    _initVideo();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _initVideo() {
    final url = l.videoUrl;
    if (url == null || url.isEmpty) return;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
  }

  Future<void> _loadReviewsAndSummary() async {
    final id = l.id;
    if (id == null) return;
    final reviews =
        await ref.read(reviewsRepositoryProvider).getListingReviews(id);
    if (reviews.isEmpty) return; // no reviews yet — skip AI summary
    setState(() => _isLoadingSummary = true);
    final summary = await ref.read(groqRepositoryProvider).summarizeReviews(
        reviews.map((r) => {'rating': r.rating, 'comment': r.comment}).toList());
    if (mounted) {
      setState(() {
        _aiSummary = summary;
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _navigate() async {
    // Opens Google Maps navigation to the spot (free, external app).
    final uri = Uri.parse(
        'google.navigation:q=${l.latitude},${l.longitude}&mode=d');
    final fallback = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${l.latitude},${l.longitude}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  /// Dials the spot's contact number, falling back to the host's profile phone.
  Future<void> _call(String? phone) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (phone == null || phone.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.noPhoneOnFile)));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotOpenDialer)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = l.id;
    final ratingAsync = id == null
        ? const AsyncValue<RatingSummary>.data(RatingSummary.empty)
        : ref.watch(_ratingProvider(id));
    final hostAsync = ref.watch(hostProfileProvider(l.ownerId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: theme.colorScheme.surfaceContainerLow,
            child: IconButton(
              icon: Icon(Icons.arrow_back,
                  color: theme.colorScheme.onSurface),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGallery(),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleRow(ratingAsync),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      _buildHost(hostAsync),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      _buildSlots(),
                      const SizedBox(height: 24),
                      _buildPricing(),
                      const SizedBox(height: 24),
                      _buildAmenities(),
                      if (l.availabilitySchedule != null) ...[
                        const SizedBox(height: 24),
                        _buildSchedule(),
                      ],
                      const SizedBox(height: 24),
                      _buildDescription(),
                      if (_videoController?.value.isInitialized == true) ...[
                        const SizedBox(height: 24),
                        _buildVideo(),
                      ],
                      const SizedBox(height: 24),
                      _buildMapPreview(hostAsync),
                      const SizedBox(height: 24),
                      _buildReviewsSection(ratingAsync),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // -------------------- Gallery --------------------
  Widget _buildGallery() {
    final theme = Theme.of(context);
    if (l.photos.isEmpty) {
      return Container(
        height: 300,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
            child: Icon(Icons.local_parking,
                size: 80, color: theme.colorScheme.primary)),
      );
    }
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            controller: _galleryController,
            itemCount: l.photos.length,
            onPageChanged: (i) => setState(() => _photoIndex = i),
            itemBuilder: (_, i) => GestureDetector(
              // Tap opens the pinch-zoom viewer; the 300px strip is too small
              // to judge a parking spot from.
              onTap: () => PhotoViewerScreen.open(context,
                  photos: l.photos, initialIndex: i),
              child: Image.network(
                l.photos[i],
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                errorBuilder: (_, _, _) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image,
                      size: 60, color: theme.colorScheme.primary),
                ),
              ),
            ),
          ),
          // Counter pill: tells the rider more photos exist at all.
          if (l.photos.length > 1)
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_photoIndex + 1}/${l.photos.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          if (l.photos.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  l.photos.length.clamp(0, 8),
                  (i) => Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _photoIndex
                          ? Colors.white
                          : Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------- Title + rating --------------------
  Widget _buildTitleRow(AsyncValue<RatingSummary> ratingAsync) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: theme.hintColor, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(l.address,
                          style: TextStyle(color: theme.hintColor))),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ratingAsync.when(
            data: (r) => Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  r.reviewCount == 0
                      ? l10n.newBadge
                      : r.avgRating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, _) => const Text('—'),
          ),
        ),
      ],
    );
  }

  // -------------------- Host --------------------
  Widget _buildHost(AsyncValue<HostProfile?> hostAsync) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return hostAsync.when(
      data: (host) {
        final name = host?.fullName?.trim();
        final joined = host?.joinedAt;
        return Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage:
                  (host?.avatarUrl != null && host!.avatarUrl!.isNotEmpty)
                      ? NetworkImage(host.avatarUrl!)
                      : null,
              child: (host?.avatarUrl == null || host!.avatarUrl!.isEmpty)
                  ? Icon(Icons.person, color: theme.colorScheme.primary)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.hostedBy(
                        name?.isNotEmpty == true ? name! : l10n.parkfinityHost),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (joined != null)
                    Text(l10n.joinedIn(DateFormat.y().format(joined)),
                        style:
                            TextStyle(color: theme.hintColor, fontSize: 14)),
                ],
              ),
            ),
            // Tap-to-dial: the listing's own number wins, host profile otherwise.
            IconButton(
              tooltip: l10n.callOwner,
              icon: const Icon(Icons.phone),
              color: theme.colorScheme.primary,
              onPressed: () => _call(l.contactPhone ?? host?.phoneNumber),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  // -------------------- Per-type slots --------------------
  Widget _buildSlots() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cap = l.slotCapacity;
    if (cap.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.availability,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cap.entries.map((e) {
            final free = l.slotAvailable[e.key] ?? 0;
            final full = free <= 0;
            // Green/grey stay literal: they carry the free-vs-full meaning and
            // must not shift with the brand colour.
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: full
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: full ? theme.dividerColor : Colors.green.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(l10n.freeOf(free, e.value),
                      style: TextStyle(
                          color: full ? theme.hintColor : Colors.green.shade700,
                          fontSize: 13)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // -------------------- Pricing tiers --------------------
  Widget _buildPricing() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tiers = <MapEntry<String, double>>[
      if (l.hourlyRate != null) MapEntry(l10n.hourly, l.hourlyRate!),
      if (l.dailyRate != null) MapEntry(l10n.daily, l.dailyRate!),
      if (l.weeklyRate != null) MapEntry(l10n.weekly, l.weeklyRate!),
      if (l.monthlyRate != null) MapEntry(l10n.monthly, l.monthlyRate!),
      if (l.yearlyRate != null) MapEntry(l10n.yearly, l.yearlyRate!),
    ];
    if (tiers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pricing,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tiers
              .map((t) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('৳${t.value.toInt()}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color:
                                    theme.colorScheme.onPrimaryContainer)),
                        Text(t.key,
                            style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.75),
                                fontSize: 12)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // -------------------- Amenities --------------------
  Widget _buildAmenities() {
    final l10n = AppLocalizations.of(context);
    final chips = <Widget>[
      if (l.hasCctv) _chip(Icons.videocam, l10n.cctvCamera),
      if (l.isCovered) _chip(Icons.roofing, l10n.coveredParking),
      if (l.hasSecurity) _chip(Icons.security, l10n.securityGuard),
      if (l.hasEvCharging) _chip(Icons.electrical_services, l10n.evCharging),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.amenities,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: chips),
      ],
    );
  }

  // -------------------- Schedule --------------------
  Widget _buildSchedule() {
    final l10n = AppLocalizations.of(context);
    final sched = l.availabilitySchedule!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.openingHours,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...sched.entries.map((e) {
          final v = e.value;
          String hours;
          if (v is Map && v['open'] != null && v['close'] != null) {
            hours = '${v['open']} – ${v['close']}';
          } else if (v == false || v == null) {
            hours = l10n.closed;
          } else {
            hours = v.toString();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(hours,
                    style: TextStyle(color: Theme.of(context).hintColor)),
              ],
            ),
          );
        }),
      ],
    );
  }

  // -------------------- Description --------------------
  Widget _buildDescription() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.description,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          l.description?.isNotEmpty == true
              ? l.description!
              : l10n.noDescription,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5),
        ),
      ],
    );
  }

  // -------------------- Video --------------------
  Widget _buildVideo() {
    final l10n = AppLocalizations.of(context);
    final c = _videoController!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.videoTour,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(c),
                IconButton(
                  iconSize: 56,
                  icon: Icon(
                    c.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white70,
                  ),
                  onPressed: () => setState(
                      () => c.value.isPlaying ? c.pause() : c.play()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -------------------- Map preview --------------------
  Widget _buildMapPreview(AsyncValue<HostProfile?> hostAsync) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.location,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(l.latitude, l.longitude),
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('spot'),
                  position: LatLng(l.latitude, l.longitude),
                ),
              },
              liteModeEnabled: true,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _navigate,
                icon: const Icon(Icons.directions),
                label: Text(l10n.navigate),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _call(l.contactPhone ?? hostAsync.value?.phoneNumber),
                icon: const Icon(Icons.phone),
                label: Text(l10n.callOwner),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------- Reviews / AI summary --------------------
  Widget _buildReviewsSection(AsyncValue<RatingSummary> ratingAsync) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = ratingAsync.value?.reviewCount ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(l10n.reviewsWithCount(count),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingSummary)
          const Center(child: CircularProgressIndicator())
        else if (_aiSummary != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Text(_aiSummary!,
                style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    height: 1.5,
                    fontStyle: FontStyle.italic)),
          )
        else
          Text(l10n.noReviewsYet, style: TextStyle(color: theme.hintColor)),
      ],
    );
  }

  Widget _chip(IconData icon, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // -------------------- Sticky bottom bar --------------------
  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final full = l.availableSlots <= 0;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5)),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.price, style: TextStyle(color: theme.hintColor)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('৳${l.hourlyRate?.toInt() ?? 0}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('/hr',
                        style:
                            TextStyle(fontSize: 16, color: theme.hintColor)),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: FilledButton(
                onPressed: full
                    ? null
                    : () => context.push('/rider/explore/checkout',
                        extra: l),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(full ? l10n.full : l10n.bookNow,
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-listing rating summary (details header + reviews count).
final _ratingProvider =
    FutureProvider.family<RatingSummary, String>((ref, listingId) {
  return ref.watch(reviewsRepositoryProvider).getRatingSummary(listingId);
});
