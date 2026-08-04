import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/listing_model.dart';
import '../controllers/listings_controller.dart';
import '../../../../core/data/repositories/storage_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../widgets/listing_form_fields.dart';

/// Edit an existing listing. Pre-fills the same fields as add, plus lets the
/// owner replace media, retune per-type slots, schedule, pricing and mode.
class EditListingScreen extends ConsumerStatefulWidget {
  final ListingModel listing;
  const EditListingScreen({super.key, required this.listing});

  @override
  ConsumerState<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends ConsumerState<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _addressController;
  late final TextEditingController _hourlyRateController;
  late final TextEditingController _dailyRateController;
  late final TextEditingController _weeklyRateController;
  late final TextEditingController _monthlyRateController;
  late final TextEditingController _yearlyRateController;

  late Map<String, int> _slotCapacity;
  late Map<String, dynamic> _schedule;
  late String _bookingMode;
  late bool _hasCCTV, _isCovered, _hasGuard, _hasEvCharging;
  late LatLng _selectedLocation;
  GoogleMapController? _mapController;

  // Existing (remote) photos kept + new local additions.
  late List<String> _existingPhotos;
  final List<File> _newImages = [];
  File? _newVideo;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final l = widget.listing;
    _titleController = TextEditingController(text: l.title);
    _descController = TextEditingController(text: l.description ?? '');
    _addressController = TextEditingController(text: l.address);
    _hourlyRateController =
        TextEditingController(text: l.hourlyRate?.toString() ?? '');
    _dailyRateController =
        TextEditingController(text: l.dailyRate?.toString() ?? '');
    _weeklyRateController =
        TextEditingController(text: l.weeklyRate?.toString() ?? '');
    _monthlyRateController =
        TextEditingController(text: l.monthlyRate?.toString() ?? '');
    _yearlyRateController =
        TextEditingController(text: l.yearlyRate?.toString() ?? '');
    _slotCapacity = Map<String, int>.from(
        l.slotCapacity.isEmpty ? {'Car': 1} : l.slotCapacity);
    _schedule = l.availabilitySchedule != null
        ? Map<String, dynamic>.from(l.availabilitySchedule!)
        : defaultWeeklySchedule();
    _bookingMode = l.bookingMode;
    _hasCCTV = l.hasCctv;
    _isCovered = l.isCovered;
    _hasGuard = l.hasSecurity;
    _hasEvCharging = l.hasEvCharging;
    _selectedLocation = LatLng(l.latitude, l.longitude);
    _existingPhotos = List<String>.from(l.photos);
  }

  Future<void> _pickImages() async {
    final imgs = await _picker.pickMultiImage();
    for (final img in imgs) {
      final f = File(img.path);
      if (await f.length() / (1024 * 1024) > kMaxImageMb) {
        _snack('${img.name} exceeds ${kMaxImageMb.toStringAsFixed(0)}MB');
        continue;
      }
      _newImages.add(f);
    }
    setState(() {});
  }

  Future<void> _pickVideo() async {
    final v = await _picker.pickVideo(source: ImageSource.gallery);
    if (v == null) return;
    final f = File(v.path);
    if (await f.length() / (1024 * 1024) > kMaxVideoMb) {
      _snack('Video exceeds ${kMaxVideoMb.toStringAsFixed(0)}MB');
      return;
    }
    setState(() => _newVideo = f);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cleanCap = <String, int>{
      for (final e in _slotCapacity.entries)
        if (e.value > 0) e.key: e.value
    };
    if (cleanCap.isEmpty) {
      _snack('Add at least one vehicle type with slots.');
      return;
    }
    final totalPhotos = _existingPhotos.length + _newImages.length;
    if (totalPhotos < 3) {
      _snack('Keep at least 3 photos.');
      return;
    }

    setState(() => _saving = true);
    try {
      final storage = ref.read(storageRepositoryProvider);
      final ownerId = widget.listing.ownerId;

      final photoUrls = List<String>.from(_existingPhotos);
      for (final f in _newImages) {
        photoUrls.add(await storage.uploadImage(f, 'listings', ownerId));
      }
      String? videoUrl = widget.listing.videoUrl;
      if (_newVideo != null) {
        videoUrl =
            await storage.uploadImage(_newVideo!, 'listings_video', ownerId);
      }

      // Preserve already-booked counts: new available = min(old available, new cap).
      final newAvailable = <String, int>{};
      cleanCap.forEach((type, cap) {
        final oldAvail = widget.listing.slotAvailable[type] ?? cap;
        newAvailable[type] = oldAvail > cap ? cap : oldAvail;
      });

      final updated = widget.listing.copyWith(
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
        slotAvailable: newAvailable,
        availabilitySchedule: _schedule,
        bookingMode: _bookingMode,
        photos: photoUrls,
        videoUrl: videoUrl,
      );

      await ref.read(myListingsProvider.notifier).editListing(updated);
      if (mounted) {
        _snack('Listing updated.');
        context.pop();
      }
    } catch (e) {
      _snack('Update failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _hourlyRateController.dispose();
    _dailyRateController.dispose();
    _weeklyRateController.dispose();
    _monthlyRateController.dispose();
    _yearlyRateController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(title: Text(l10n.editListing), elevation: 0),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photos (existing + new)
              Text(l10n.photos,
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._existingPhotos.map((url) => _thumb(
                        Image.network(url,
                            width: 90, height: 90, fit: BoxFit.cover),
                        onRemove: () =>
                            setState(() => _existingPhotos.remove(url)),
                      )),
                  ..._newImages.map((f) => _thumb(
                        Image.file(f, width: 90, height: 90, fit: BoxFit.cover),
                        onRemove: () => setState(() => _newImages.remove(f)),
                      )),
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add_a_photo),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.videocam),
                label: Text(_newVideo != null
                    ? 'New video selected'
                    : 'Replace video (optional)'),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                    labelText: 'Address', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              SlotCapacityEditor(
                capacity: _slotCapacity,
                onChanged: (m) => setState(() => _slotCapacity = m),
              ),
              const SizedBox(height: 24),

              Text(l10n.pricing,
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _hourlyRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: l10n.hourly,
                            border: const OutlineInputBorder()),
                        validator: (v) =>
                            v!.isEmpty ? l10n.required : null)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: _dailyRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: l10n.daily,
                            border: const OutlineInputBorder()))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _weeklyRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: l10n.weekly,
                            border: const OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: _monthlyRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: l10n.monthly,
                            border: const OutlineInputBorder()))),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _yearlyRateController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: l10n.yearly,
                      border: const OutlineInputBorder())),
              const SizedBox(height: 24),

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
              const SizedBox(height: 24),

              BookingModeSelector(
                mode: _bookingMode,
                onChanged: (m) => setState(() => _bookingMode = m),
              ),
              const SizedBox(height: 24),

              WeeklyScheduleEditor(
                schedule: _schedule,
                onChanged: (s) => setState(() => _schedule = s),
              ),
              const SizedBox(height: 24),

              Text(l10n.location,
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(alignment: Alignment.center, children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                          target: _selectedLocation, zoom: 15),
                      onMapCreated: (c) => _mapController = c,
                      onCameraMove: (p) => _selectedLocation = p.target,
                      zoomControlsEnabled: false,
                    ),
                    Icon(Icons.location_on,
                        size: 44, color: Theme.of(context).colorScheme.primary),
                  ]),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary),
                child: _saving
                    ? CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onPrimary)
                    : Text(l10n.saveChanges,
                        style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(Widget img, {required VoidCallback onRemove}) {
    return Stack(children: [
      ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
      Positioned(
        right: 0,
        top: 0,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            child: Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.surfaceContainerLow),
          ),
        ),
      ),
    ]);
  }
}
