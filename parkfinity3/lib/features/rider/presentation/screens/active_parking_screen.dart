import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/rider_bookings_provider.dart';
import '../controllers/bookings_controller.dart';
import '../../../../shared/data/models/booking_model.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../wallet/presentation/controllers/wallet_provider.dart';
import '../../../parking/data/qr_repository.dart';
import '../../../parking/presentation/screens/qr_scan_screen.dart';
import '../../../../l10n/generated/app_localizations.dart';

class ActiveParkingScreen extends ConsumerStatefulWidget {
  const ActiveParkingScreen({super.key});

  @override
  ConsumerState<ActiveParkingScreen> createState() => _ActiveParkingScreenState();
}

class _ActiveParkingScreenState extends ConsumerState<ActiveParkingScreen> {

  int _secondsRemaining = 0;
  int _totalSeconds = 1;
  Timer? _timer;
  BookingModel? _activeBooking;

  @override
  void initState() {
    super.initState();
    // We will start timer when data is loaded
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _navigate(BookingModel booking) async {
    final l = booking.listing;
    if (l == null) return;
    final uri = Uri.parse('google.navigation:q=${l.latitude},${l.longitude}&mode=d');
    final fallback = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${l.latitude},${l.longitude}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.couldNotOpenMaps)));
      }
    }
  }

  Future<void> _cancel(BookingModel booking) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelBookingQ),
        content: Text(l10n.cancelBookingBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.keep)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.cancelIt)),
        ],
      ),
    );
    if (confirm != true) return;

    final user = ref.read(authStateChangesProvider).value?.session?.user;
    if (user == null || booking.id == null) return;
    try {
      final msg = await ref.read(bookingsControllerProvider.notifier).cancelBooking(booking.id!, user.id);
      ref.invalidate(riderBookingsProvider);
      ref.invalidate(walletControllerProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim())));
      }
    }
  }

  Future<void> _showExtendSheet(BookingModel booking) async {
    final l10n = AppLocalizations.of(context);
    String durationType = booking.durationType ?? 'Hourly';
    int count = 1;
    String durationLabel(String t) => switch (t) {
          'Hourly' => l10n.hourly,
          'Daily' => l10n.daily,
          'Weekly' => l10n.weekly,
          'Monthly' => l10n.monthly,
          'Yearly' => l10n.yearly,
          _ => t,
        };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.extendParking,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: durationType,
                      decoration: InputDecoration(labelText: l10n.duration, border: const OutlineInputBorder()),
                      items: const ['Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly']
                          .map((t) => DropdownMenuItem(value: t, child: Text(durationLabel(t))))
                          .toList(),
                      onChanged: (v) => setModal(() => durationType = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                      onPressed: () { if (count > 1) setModal(() => count--); },
                      icon: const Icon(Icons.remove_circle_outline)),
                  Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => setModal(() => count++),
                      icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
              const SizedBox(height: 8),
              Text(l10n.serverPricesFinal,
                  style: TextStyle(
                      color: Theme.of(ctx).hintColor, fontSize: 12)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _submitExtend(booking, durationType, count);
                  },
                  child: Text(l10n.confirmPay),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitExtend(BookingModel booking, String durationType, int count) async {
    final user = ref.read(authStateChangesProvider).value?.session?.user;
    if (user == null || booking.id == null) return;
    try {
      final updated = await ref.read(bookingsControllerProvider.notifier).extendBooking(
            bookingId: booking.id!,
            riderId: user.id,
            durationType: durationType,
            durationCount: count,
          );
      ref.invalidate(riderBookingsProvider);
      ref.invalidate(walletControllerProvider);
      // Reset timer against the new end time.
      if (mounted) {
        setState(() {
          _activeBooking = null; // force timer re-sync on rebuild
        });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.extendedTo(updated.endTime.toLocal().toString()))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim())));
      }
    }
  }

  /// Opens the camera scanner and refreshes the booking list on success. The
  /// server decides whether the scan is valid, so the button stays enabled and
  /// the message from `check_in` / `check_out` is what the rider sees.
  Future<void> _scan(BookingModel booking, ScanMode mode) async {
    final res = await context.push<ScanResult>(
        mode == ScanMode.checkIn ? '/scan/in' : '/scan/out');
    if (res == null || !mounted) return;

    ref.invalidate(riderBookingsProvider);
    ref.invalidate(walletControllerProvider);
    setState(() => _activeBooking = null); // force timer re-sync
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(res.message)));
  }

  String get _formattedTime {
    if (_secondsRemaining <= 0) return '00:00:00';
    int hours = _secondsRemaining ~/ 3600;
    int minutes = (_secondsRemaining % 3600) ~/ 60;
    int seconds = _secondsRemaining % 60;
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bookingsAsync = ref.watch(riderBookingsProvider);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activeSession),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/rider/explore'),
        ),
      ),
      body: SafeArea(
        child: bookingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('${l10n.error}: $err')),
          data: (bookings) {
            // Find an active booking (Confirmed/Active/Pending, still running)
            final now = DateTime.now();
            const liveStatuses = {'Confirmed', 'Active', 'Pending'};
            final activeBookings = bookings
                .where((b) => liveStatuses.contains(b.status) && b.endTime.isAfter(now))
                .toList();
            
            if (activeBookings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_parking_rounded,
                        size: 64, color: theme.hintColor),
                    const SizedBox(height: 16),
                    Text(l10n.noActiveBookings,
                        style: TextStyle(fontSize: 20, color: theme.hintColor)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/rider/explore'),
                      child: Text(l10n.findParkingBtn),
                    ),
                  ],
                ),
              );
            }

            final booking = activeBookings.first;
            
            // Only update timer state if we switched to a new booking
            if (_activeBooking?.id != booking.id) {
              _activeBooking = booking;
              _totalSeconds = booking.endTime.difference(booking.startTime).inSeconds;
              if (_totalSeconds <= 0) _totalSeconds = 1;
              _secondsRemaining = booking.endTime.difference(now).inSeconds;
              if (_secondsRemaining < 0) _secondsRemaining = 0;
              _startTimer();
            }

            double progress = _secondsRemaining / _totalSeconds;
            if (progress < 0) progress = 0;
            if (progress > 1) progress = 1;

            return Padding(
              padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.timeRemaining,
                style: TextStyle(
                    fontSize: 20,
                    color: theme.hintColor,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              
              // Circular Timer
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.1 ? Colors.green : theme.colorScheme.error,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formattedTime,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (progress <= 0.1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            l10n.expiringSoon,
                            style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold),
                          ),
                        )
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 64),
              
              // Parking Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: theme.colorScheme.primary, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(booking.listing?.title ?? l10n.parkingSpot, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(booking.listing?.address ?? '',
                              style: TextStyle(color: theme.hintColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showExtendSheet(booking),
                      icon: const Icon(Icons.add_alarm),
                      label: Text(l10n.extend),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigate(booking),
                      icon: const Icon(Icons.navigation),
                      label: Text(l10n.navigate),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Before check-in the rider scans to start; once Active the same
              // poster ends the session and settles any overstay charge.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _scan(
                    booking,
                    booking.checkedInAt == null
                        ? ScanMode.checkIn
                        : ScanMode.checkOut,
                  ),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(booking.checkedInAt == null
                      ? l10n.checkIn
                      : l10n.checkOut),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => _cancel(booking),
                icon: Icon(Icons.cancel_outlined,
                    color: Theme.of(context).colorScheme.error),
                label: Text(l10n.cancelBooking,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
              const SizedBox(height: 16),
            ],
          ),
            );
          },
        ),
      ),
    );
  }
}
