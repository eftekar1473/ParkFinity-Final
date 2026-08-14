import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/listing_model.dart';
import '../controllers/listings_controller.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../parking/data/places_repository.dart';
import '../../../../core/data/repositories/storage_repository.dart';
import '../widgets/listing_form_fields.dart';
import '../../../../l10n/generated/app_localizations.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({super.key});

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Media
  final List<File> _imageFiles = [];
  File? _videoFile;
  final ImagePicker _picker = ImagePicker();

  // Location & Autocomplete
  LatLng _selectedLocation = const LatLng(23.8103, 90.4125); // Default Dhaka
  GoogleMapController? _mapController;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _locating = false;
  bool _submitting = false;

  // Amenities
  bool _hasCCTV = false;
  bool _isCovered = false;
  bool _hasGuard = false;
  bool _hasEvCharging = false;

  // Text Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();

  // Pricing
  final _hourlyRateController = TextEditingController();
  final _dailyRateController = TextEditingController();
  final _weeklyRateController = TextEditingController();
  final _monthlyRateController = TextEditingController();
  final _yearlyRateController = TextEditingController();

  // Per-type slots + schedule + mode (shared editor state)
  final Map<String, int> _slotCapacity = {'Car': 1};
  Map<String, dynamic> _schedule = defaultWeeklySchedule();
  String _bookingMode = 'instant';

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.of(context);
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty) return;
    final accepted = <File>[];
    for (final img in images) {
      final file = File(img.path);
      final mb = await file.length() / (1024 * 1024);
      if (mb > kMaxImageMb) {
        _snack(l10n.photoTooLarge(
            img.name, mb.toStringAsFixed(1), kMaxImageMb.toStringAsFixed(0)));
        continue;
      }
      accepted.add(file);
    }
    setState(() => _imageFiles.addAll(accepted));
  }

  Future<void> _pickVideo() async {
    final l10n = AppLocalizations.of(context);
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    final file = File(video.path);
    final mb = await file.length() / (1024 * 1024);
    if (mb > kMaxVideoMb) {
      _snack(l10n.videoTooLarge(mb.toStringAsFixed(1), kMaxVideoMb.toStringAsFixed(0)));
      return;
    }
    setState(() => _videoFile = file);
  }

  // -------------------- Location Search & Autocomplete --------------------

  void _onSearchQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetchSuggestions(value));
  }

  Future<void> _fetchSuggestions(String value) async {
    final results = await ref.read(placesRepositoryProvider).autocomplete(
          value,
          lat: _selectedLocation.latitude,
          lng: _selectedLocation.longitude,
        );
    if (!mounted || _searchController.text.trim() != value.trim()) return;
    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  Future<void> _chooseSuggestion(PlaceSuggestion s) async {
    _searchFocus.unfocus();
    setState(() {
      _suggestions = const [];
      _searching = true;
    });

    final loc = await ref.read(placesRepositoryProvider).resolve(s);
    if (!mounted) return;
    setState(() => _searching = false);

    if (loc == null) {
      _snack(AppLocalizations.of(context).locationNotFound);
      return;
    }

    _searchController.text = s.title;
    final target = LatLng(loc.lat, loc.lng);
    setState(() {
      _selectedLocation = target;
      if (_addressController.text.isEmpty || _addressController.text.trim() == s.title) {
        _addressController.text = loc.address.isNotEmpty ? loc.address : s.title;
      }
    });

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _suggestions = const [];
      _searching = false;
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final ok = await _ensureLocationPermission();
      if (!ok) {
        if (!mounted) return;
        _snack(AppLocalizations.of(context).locationPermissionDenied);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() => _selectedLocation = target);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
      // Reverse-geocode to prefill the address field.
      try {
        final placemarks =
            await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty && _addressController.text.isEmpty) {
          final p = placemarks.first;
          _addressController.text = [p.street, p.subLocality, p.locality]
              .where((e) => (e ?? '').isNotEmpty)
              .join(', ');
        }
      } catch (_) {/* reverse geocode is best-effort */}
    } catch (e) {
      if (!mounted) return;
      _snack(AppLocalizations.of(context).couldNotGetLocation('$e'));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _submitForm() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_imageFiles.length < 3) {
      _snack(l10n.min3Photos);
      return;
    }
    if (_slotCapacity.isEmpty || _slotCapacity.values.every((v) => v <= 0)) {
      _snack(l10n.addVehicleTypeSlot);
      return;
    }

    final user = ref.read(authStateChangesProvider).value?.session?.user;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      final storageRepo = ref.read(storageRepositoryProvider);
      _snack(l10n.uploadingMedia);

      final photoUrls = <String>[];
      for (final file in _imageFiles) {
        photoUrls.add(await storageRepo.uploadImage(file, 'listings', user.id));
      }

      String? videoUrl;
      if (_videoFile != null) {
        videoUrl = await storageRepo.uploadImage(_videoFile!, 'listings_video', user.id);
      }

      final cleanCap = <String, int>{
        for (final e in _slotCapacity.entries)
          if (e.value > 0) e.key: e.value
      };

      final listing = ListingModel(
        ownerId: user.id,
        title: _titleController.text,
        description: _descController.text,
        address: _addressController.text,
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        isCovered: _isCovered,
        hasSecurity: _hasGuard,
        hasCctv: _hasCCTV,
        hasEvCharging: _hasEvCharging,
        allowedVehicleTypes: cleanCap.keys.toList(),
        hourlyRate: double.tryParse(_hourlyRateController.text),
        dailyRate: double.tryParse(_dailyRateController.text),
        weeklyRate: double.tryParse(_weeklyRateController.text),
        monthlyRate: double.tryParse(_monthlyRateController.text),
        yearlyRate: double.tryParse(_yearlyRateController.text),
        slotCapacity: cleanCap,
        slotAvailable: cleanCap, // fresh listing: all free
        availabilitySchedule: _schedule,
        bookingMode: _bookingMode,
        photos: photoUrls,
        videoUrl: videoUrl,
      );

      await ref.read(myListingsProvider.notifier).addListing(listing);

      if (mounted) {
        _snack(l10n.listingPublished);
        context.pop();
      }
    } catch (e) {
      if (mounted) _snack(l10n.failedUpload('$e'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocus.dispose();
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _hourlyRateController.dispose();
    _dailyRateController.dispose();
    _weeklyRateController.dispose();
    _monthlyRateController.dispose();
    _yearlyRateController.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isBusy = _submitting || ref.watch(myListingsProvider).isLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: Text(l10n.addParkingSpot),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Photos
              Text(l10n.spotPhotosMin3,
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_imageFiles.isEmpty) ...[
                const SizedBox(height: 8),
                Text(l10n.noPhotosSelected,
                    style: TextStyle(color: Theme.of(context).hintColor)),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (int i = 0; i < _imageFiles.length; i++)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_imageFiles[i],
                              width: 90, height: 90, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _imageFiles.removeAt(i)),
                            child: Container(
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  InkWell(
                    onTap: _pickImages,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 4),
                          Text(l10n.addPhotos, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Video
              Text(l10n.spotVideoRequired,
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.videocam),
                label: Text(_videoFile != null
                    ? '${l10n.videoSelected} (${(_videoFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB)'
                    : l10n.addVideo),
              ),
              const SizedBox(height: 32),

              // 2. Details
              Text(l10n.spotDetails,
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                    labelText: l10n.listingTitle, border: const OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: l10n.description, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                    labelText: l10n.fullAddress, border: const OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 32),

              // 3. Per-type slots
              SlotCapacityEditor(
                capacity: _slotCapacity,
                onChanged: (m) => setState(() {
                  _slotCapacity
                    ..clear()
                    ..addAll(m);
                }),
              ),
              const SizedBox(height: 32),

              // 4. Pricing
              Text(l10n.pricingOptions,
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _hourlyRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: l10n.rateBdt(l10n.hourly),
                            border: const OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? l10n.req : null)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: _dailyRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: l10n.rateBdt(l10n.daily),
                            border: const OutlineInputBorder()))),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _weeklyRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: l10n.rateBdt(l10n.weekly),
                            border: const OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: _monthlyRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: l10n.rateBdt(l10n.monthly),
                            border: const OutlineInputBorder()))),
              ]),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _yearlyRateController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: l10n.rateBdt(l10n.yearly), border: const OutlineInputBorder())),
              const SizedBox(height: 32),

              // 5. Amenities
              Text(l10n.amenities,
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              CheckboxListTile(
                  title: Text(l10n.cctvCamera),
                  value: _hasCCTV,
                  onChanged: (v) => setState(() => _hasCCTV = v!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero),
              CheckboxListTile(
                  title: Text(l10n.coveredParking),
                  value: _isCovered,
                  onChanged: (v) => setState(() => _isCovered = v!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero),
              CheckboxListTile(
                  title: Text(l10n.securityGuard),
                  value: _hasGuard,
                  onChanged: (v) => setState(() => _hasGuard = v!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero),
              CheckboxListTile(
                  title: Text(l10n.evCharging),
                  value: _hasEvCharging,
                  onChanged: (v) => setState(() => _hasEvCharging = v!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero),
              const SizedBox(height: 32),

              // 6. Booking mode
              BookingModeSelector(
                mode: _bookingMode,
                onChanged: (m) => setState(() => _bookingMode = m),
              ),
              const SizedBox(height: 32),

              // 7. Availability schedule
              WeeklyScheduleEditor(
                schedule: _schedule,
                onChanged: (s) => setState(() => _schedule = s),
              ),
              const SizedBox(height: 32),

              // 8. Map & Location Autocomplete
              Text(l10n.exactLocation,
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _onSearchQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchLocationHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: _clearSearch,
                        )
                      : null,
                ),
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).cardColor,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.place_outlined,
                              color: Theme.of(context).colorScheme.primary, size: 20),
                          title: Text(s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: s.subtitle.isNotEmpty
                              ? Text(s.subtitle,
                                  maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                          onTap: () => _chooseSuggestion(s),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(l10n.useMyLocation),
              ),
              const SizedBox(height: 16),
              Container(
                height: 250,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                            target: _selectedLocation, zoom: 15),
                        onMapCreated: (c) => _mapController = c,
                        onCameraMove: (position) {
                          _selectedLocation = position.target;
                        },
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                      Icon(Icons.location_on,
                          size: 48, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

              ElevatedButton(
                onPressed: isBusy ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary),
                child: isBusy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(l10n.publishListing,
                        style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
