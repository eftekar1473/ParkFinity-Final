import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/data/models/booking_model.dart';
import '../../data/my_profile_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Full record of one booking. Same screen for both sides — the only difference
/// is who the "call" button dials: a rider calls the owner, an owner calls the
/// rider.
class BookingDetailsScreen extends ConsumerWidget {
  final BookingModel booking;

  /// True when the viewer owns the listing.
  final bool asOwner;

  const BookingDetailsScreen({
    super.key,
    required this.booking,
    this.asOwner = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final stamp = DateFormat('EEE d MMM yyyy, h:mm a');

    // Counterpart: whose number to dial. Owner id lives on the nested listing,
    // rider id on the booking itself.
    final counterpartId =
        asOwner ? booking.riderId : booking.listing?.ownerId;
    final counterpartAsync = counterpartId == null
        ? null
        : ref.watch(publicProfileProvider(counterpartId));
    final phone = counterpartAsync?.value?.phoneNumber ??
        booking.listing?.contactPhone;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookingDetails)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Section(
            title: booking.listing?.title ?? l10n.parkingSpot,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16, color: theme.hintColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        booking.listing?.address ?? l10n.unknownAddress,
                        style: TextStyle(color: theme.hintColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatusPill(status: booking.status),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _Section(
            title: l10n.bookingDetails,
            child: Column(
              children: [
                _Row(label: l10n.startTime, value: stamp.format(booking.startTime.toLocal())),
                _Row(label: l10n.endTime, value: stamp.format(booking.endTime.toLocal())),
                if (booking.checkedInAt != null)
                  _Row(
                      label: l10n.checkedIn,
                      value: stamp.format(booking.checkedInAt!.toLocal())),
                if (booking.checkedOutAt != null)
                  _Row(
                      label: l10n.checkedOut,
                      value: stamp.format(booking.checkedOutAt!.toLocal())),
                if (booking.vehicleType != null)
                  _Row(label: l10n.vehicle, value: booking.vehicleType!),
                if (booking.durationType != null)
                  _Row(label: l10n.duration, value: booking.durationType!),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _Section(
            title: l10n.paymentBreakdown,
            child: Column(
              children: [
                _Row(
                    label: l10n.baseAmount,
                    value: money.format(booking.baseAmount)),
                if (booking.overstayAmount > 0)
                  _Row(
                    label: l10n.overstayCharge,
                    value: money.format(booking.overstayAmount),
                    valueColor: theme.colorScheme.error,
                  ),
                // Commission only concerns the owner's payout; riders never
                // paid it separately.
                if (asOwner)
                  _Row(
                      label: l10n.commission,
                      value: money.format(booking.commissionAmount)),
                const Divider(height: 24),
                _Row(
                  label: asOwner ? l10n.earnings : l10n.totalPaid,
                  value: money.format(
                      asOwner ? booking.ownerEarnings : booking.totalAmount),
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (!asOwner &&
              (booking.status == 'Active' ||
                  booking.status == 'Confirmed' ||
                  booking.status == 'Pending') &&
              booking.endTime.isAfter(DateTime.now())) ...[
            FilledButton.icon(
              onPressed: () => context.push('/active_session'),
              icon: const Icon(Icons.timer_outlined),
              label: Text(l10n.activeSession),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _call(context, phone),
                  icon: const Icon(Icons.phone),
                  label: Text(asOwner ? l10n.callRider : l10n.callOwner),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _navigate(context),
                  icon: const Icon(Icons.navigation),
                  label: Text(l10n.navigate),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context, String? phone) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (phone == null || phone.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.noPhoneOnFile)));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotOpenDialer)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotOpenDialer)));
    }
  }

  Future<void> _navigate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l = booking.listing;
    if (l == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotOpenMaps)));
      return;
    }
    // Turn-by-turn intent first; falls back to the web maps URL on devices
    // without the Google Maps app.
    final nav =
        Uri.parse('google.navigation:q=${l.latitude},${l.longitude}&mode=d');
    final web = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${l.latitude},${l.longitude}');
    try {
      if (await canLaunchUrl(nav)) {
        await launchUrl(nav, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(web, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotOpenMaps)));
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: TextStyle(color: Theme.of(context).hintColor)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                fontSize: bold ? 16 : null,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      'Active' => (l10n.statusActive, Colors.green),
      'Confirmed' => (l10n.statusUpcoming, Colors.orange),
      'Pending' => (l10n.statusUpcoming, Colors.orange),
      'Completed' => (l10n.statusCompleted, Colors.blue),
      'Cancelled' => (l10n.statusCancelled, theme.colorScheme.error),
      _ => (status, theme.hintColor),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
