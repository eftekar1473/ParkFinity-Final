import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../owner/presentation/controllers/listings_controller.dart';
import '../../../../core/data/repositories/groq_repository.dart';
import '../../../owner/data/models/listing_model.dart';

class ExploreMapScreen extends ConsumerStatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  ConsumerState<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends ConsumerState<ExploreMapScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final TextEditingController _searchController = TextEditingController();

  // Default to Dhaka, Bangladesh as a starting point
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(23.8103, 90.4125),
    zoom: 14.4746,
  );

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    } 

    _goToCurrentLocation();
  }

  Future<void> _goToCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition();
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 16.0,
      )
    ));
    // Removed dummy marker logic, we now use Riverpod to fetch live markers
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;

    try {
      List<Location> locations = await Geocoding().locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final GoogleMapController controller = await _controller.future;
        await controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(location.latitude, location.longitude),
            zoom: 15.0,
          )
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not found. Please try another search.')),
        );
      }
    }
  }

  void _showAskAIBottomSheet(List<ListingModel> listings) {
    final aiController = TextEditingController();
    bool isAiLoading = false;
    String aiResponse = '';

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
                  const Text(
                    'Ask ParkFinity AI ✨',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tell us what kind of parking you need (e.g. "Cheapest covered spot near Gulshan")'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: aiController,
                    decoration: InputDecoration(
                      hintText: 'Your preference...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isAiLoading ? null : () async {
                      if (aiController.text.trim().isEmpty) return;
                      setModalState(() {
                        isAiLoading = true;
                        aiResponse = '';
                      });
                      
                      final groqRepo = ref.read(groqRepositoryProvider);
                      final response = await groqRepo.getSmartRecommendations(listings, aiController.text);
                      
                      setModalState(() {
                        isAiLoading = false;
                        aiResponse = response;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isAiLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('Ask AI'),
                  ),
                  if (aiResponse.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurple.shade200),
                      ),
                      child: Text(
                        aiResponse,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
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
    final listingsAsync = ref.watch(allActiveListingsProvider);

    // Compute active markers from DB
    final Set<Marker> dynamicMarkers = listingsAsync.maybeWhen(
      data: (listings) {
        return listings.map((listing) {
          return Marker(
            markerId: MarkerId(listing.id ?? listing.hashCode.toString()),
            position: LatLng(listing.latitude, listing.longitude),
            infoWindow: InfoWindow(
              title: listing.title,
              snippet: '৳${listing.hourlyRate?.toInt() ?? 0} / hour - Tap to view',
              onTap: () {
                context.push('/rider/explore/details', extra: listing);
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          );
        }).toSet();
      },
      orElse: () => {},
    );

    // Combine with local markers (if any)
    final allMarkers = _markers.union(dynamicMarkers);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: allMarkers,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),
          
          // Floating Search Bar
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: _searchPlace,
                decoration: InputDecoration(
                  hintText: 'Where do you want to park?',
                  prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.deepPurple),
                    onPressed: () {
                      // Show Filter Bottomsheet
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          
          // Floating Ask AI Button
          Positioned(
            bottom: 100, // Above current location button
            right: 16,
            child: FloatingActionButton(
              heroTag: 'askAI',
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.auto_awesome, color: Colors.white),
              onPressed: () {
                final currentListings = listingsAsync.value ?? [];
                _showAskAIBottomSheet(currentListings);
              },
            ),
          ),
          
          // Floating Current Location Button
          Positioned(
            bottom: 32,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'currentLocation',
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.deepPurple),
              onPressed: _goToCurrentLocation,
            ),
          ),
        ],
      ),
    );
  }
}
