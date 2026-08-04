import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/models/listing_filter.dart';
import '../../../owner/presentation/widgets/listing_form_fields.dart';

/// Bottom sheet to edit a [ListingFilter]. Returns the new filter via
/// [showFilterSheet]; returns null if dismissed without applying.
Future<ListingFilter?> showFilterSheet(
  BuildContext context,
  ListingFilter current,
) {
  return showModalBottomSheet<ListingFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  final ListingFilter initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ListingFilter _f;

  @override
  void initState() {
    super.initState();
    _f = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.filters,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _f = ListingFilter.none),
                  child: Text(l10n.reset),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Distance
            _label(l10n.distance,
                _f.maxDistanceKm == null
                    ? l10n.anyValue
                    : '${_f.maxDistanceKm!.toStringAsFixed(0)} km'),
            Slider(
              value: (_f.maxDistanceKm ?? 25).clamp(1, 25),
              min: 1,
              max: 25,
              divisions: 24,
              activeColor: Theme.of(context).colorScheme.primary,
              label: '${(_f.maxDistanceKm ?? 25).toStringAsFixed(0)} km',
              onChanged: (v) => setState(() =>
                  _f = _f.copyWith(maxDistanceKm: v >= 25 ? null : v)),
            ),

            // Price
            _label(l10n.maxPricePerHour,
                _f.maxHourlyRate == null
                    ? l10n.anyValue
                    : '৳${_f.maxHourlyRate!.toStringAsFixed(0)}'),
            Slider(
              value: (_f.maxHourlyRate ?? 500).clamp(20, 500),
              min: 20,
              max: 500,
              divisions: 48,
              activeColor: Theme.of(context).colorScheme.primary,
              label: '৳${(_f.maxHourlyRate ?? 500).toStringAsFixed(0)}',
              onChanged: (v) => setState(() =>
                  _f = _f.copyWith(maxHourlyRate: v >= 500 ? null : v)),
            ),

            // Rating
            _label(l10n.minimumRating,
                _f.minRating == 0
                    ? l10n.anyValue
                    : '${_f.minRating.toStringAsFixed(0)}★+'),
            Wrap(
              spacing: 8,
              children: [0, 3, 4, 5].map((r) {
                final selected = _f.minRating == r;
                return ChoiceChip(
                  label: Text(r == 0 ? l10n.anyValue : '$r★+'),
                  selected: selected,
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  onSelected: (_) =>
                      setState(() => _f = _f.copyWith(minRating: r.toDouble())),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Vehicle type
            Text(l10n.vehicleType,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text(l10n.anyValue),
                  selected: _f.vehicleType == null,
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  onSelected: (_) => setState(
                      () => _f = _f.copyWith(clearVehicleType: true)),
                ),
                ...kVehicleTypes.map((t) => ChoiceChip(
                      label: Text(t),
                      selected: _f.vehicleType == t,
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                      onSelected: (_) =>
                          setState(() => _f = _f.copyWith(vehicleType: t)),
                    )),
              ],
            ),
            const SizedBox(height: 16),

            // Amenities
            Text(l10n.amenities,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            _switch(l10n.coveredParking, _f.requireCovered,
                (v) => setState(() => _f = _f.copyWith(requireCovered: v))),
            _switch(l10n.onSiteSecurity, _f.requireSecurity,
                (v) => setState(() => _f = _f.copyWith(requireSecurity: v))),
            _switch(l10n.cctvCamera, _f.requireCctv,
                (v) => setState(() => _f = _f.copyWith(requireCctv: v))),
            _switch(l10n.evCharging, _f.requireEvCharging,
                (v) => setState(() => _f = _f.copyWith(requireEvCharging: v))),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _f),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_f.isActive
                    ? l10n.applyFilters(_f.activeCount)
                    : l10n.showAll),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String title, String value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(value, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      );

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeThumbColor: Theme.of(context).colorScheme.primary,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      );
}
