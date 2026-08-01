import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/rider_bookings_provider.dart';
import '../../../../shared/data/models/booking_model.dart';

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

  String get _formattedTime {
    if (_secondsRemaining <= 0) return '00:00:00';
    int hours = _secondsRemaining ~/ 3600;
    int minutes = (_secondsRemaining % 3600) ~/ 60;
    int seconds = _secondsRemaining % 60;
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(riderBookingsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Active Session'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/rider/explore'),
        ),
      ),
      body: SafeArea(
        child: bookingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (bookings) {
            // Find an active booking
            final now = DateTime.now();
            final activeBookings = bookings.where((b) => b.status == 'Pending' && b.endTime.isAfter(now)).toList();
            
            if (activeBookings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_parking_rounded, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No Active Bookings', style: TextStyle(fontSize: 20, color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/rider/explore'),
                      child: const Text('Find Parking'),
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
              const Text(
                'Time Remaining',
                style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold),
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
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.1 ? Colors.green : Colors.red,
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
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Expiring soon!',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.deepPurple, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(booking.listing?.title ?? 'Parking Spot', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(booking.listing?.address ?? '', style: const TextStyle(color: Colors.grey)),
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
                      onPressed: () {},
                      icon: const Icon(Icons.add_alarm),
                      label: const Text('Extend'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.deepPurple,
                        side: const BorderSide(color: Colors.deepPurple),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
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
