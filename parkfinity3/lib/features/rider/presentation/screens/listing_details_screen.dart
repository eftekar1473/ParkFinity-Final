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

  ListingModel get l => widget.listing;

  @override
  void initState() {
    super.initState();
    _loadReviewsAndSummary();
    _initVideo();
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final id = l.id;
    final ratingAsync = id == null
        ? const AsyncValue<RatingSummary>.data(RatingSummary.empty)
        : ref.watch(_ratingProvider(id));
    final hostAsync = ref.watch(hostProfileProvider(l.ownerId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                      _buildMapPreview(),
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
    if (l.photos.isEmpty) {
      return Container(
        height: 300,
        color: Colors.deepPurple.shade100,
        child: const Center(
            child: Icon(Icons.local_parking,
                size: 80, color: Colors.deepPurple)),
      );
    }
    return SizedBox(
      height: 300,
      child: PageView.builder(
        itemCount: l.photos.length,
        itemBuilder: (_, i) => Image.network(
          l.photos[i],
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: Colors.deepPurple.shade100,
            child: const Icon(Icons.broken_image,
                size: 60, color: Colors.deepPurple),
          ),
        ),
      ),
    );
  }

  // -------------------- Title + rating --------------------
  Widget _buildTitleRow(AsyncValue<RatingSummary> ratingAsync) {
    final l10n = AppLocalizations.of(context);
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
                  const Icon(Icons.location_on, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(l.address,
                          style: TextStyle(color: Colors.grey[700]))),
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
    return hostAsync.when(
      data: (host) {
        final name = host?.fullName?.trim();
        final joined = host?.joinedAt;
        return Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.deepPurple.shade100,
              backgroundImage:
                  (host?.avatarUrl != null && host!.avatarUrl!.isNotEmpty)
                      ? NetworkImage(host.avatarUrl!)
                      : null,
              child: (host?.avatarUrl == null || host!.avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.deepPurple)
                  : null,
            ),
            const SizedBox(width: 16),
            Column(
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
                          TextStyle(color: Colors.grey[600], fontSize: 14)),
              ],
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
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: full ? Colors.grey.shade200 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: full ? Colors.grey : Colors.green.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(l10n.freeOf(free, e.value),
                      style: TextStyle(
                          color: full ? Colors.grey[700] : Colors.green[800],
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
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('৳${t.value.toInt()}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(t.key,
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 12)),
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
                Text(hours, style: TextStyle(color: Colors.grey[700])),
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
          style: TextStyle(color: Colors.grey[800], height: 1.5),
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
  Widget _buildMapPreview() {
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
        OutlinedButton.icon(
          onPressed: _navigate,
          icon: const Icon(Icons.directions),
          label: Text(l10n.navigate),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            side: const BorderSide(color: Colors.deepPurple),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          ),
        ),
      ],
    );
  }

  // -------------------- Reviews / AI summary --------------------
  Widget _buildReviewsSection(AsyncValue<RatingSummary> ratingAsync) {
    final l10n = AppLocalizations.of(context);
    final count = ratingAsync.value?.reviewCount ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.deepPurple),
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
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.shade100),
            ),
            child: Text(_aiSummary!,
                style: TextStyle(
                    color: Colors.deepPurple.shade900,
                    height: 1.5,
                    fontStyle: FontStyle.italic)),
          )
        else
          Text(l10n.noReviewsYet,
              style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // -------------------- Sticky bottom bar --------------------
  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context);
    final full = l.availableSlots <= 0;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
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
                Text(l10n.price, style: const TextStyle(color: Colors.grey)),                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('৳${l.hourlyRate?.toInt() ?? 0}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text('/hr',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: ElevatedButton(
                onPressed: full
                    ? null
                    : () => context.push('/rider/explore/checkout',
                        extra: l),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
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
