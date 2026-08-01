import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../owner/data/models/listing_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/repositories/groq_repository.dart';

class ListingDetailsScreen extends ConsumerStatefulWidget {
  final ListingModel listing;

  const ListingDetailsScreen({super.key, required this.listing});

  @override
  ConsumerState<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends ConsumerState<ListingDetailsScreen> {
  String? _aiSummary;
  bool _isLoadingSummary = true;

  @override
  void initState() {
    super.initState();
    _fetchAiSummary();
  }

  Future<void> _fetchAiSummary() async {
    final groqRepo = ref.read(groqRepositoryProvider);
    // Mock reviews for demonstration
    final mockReviews = [
      {'rating': 5, 'comment': 'Great spot, very secure with CCTV.'},
      {'rating': 4, 'comment': 'Good location but a bit tight to park a large SUV.'},
      {'rating': 5, 'comment': 'Host is very friendly, zero issues.'},
      {'rating': 3, 'comment': 'Pricy for the area, but convenient.'},
    ];
    
    final summary = await groqRepo.summarizeReviews(mockReviews);
    if (mounted) {
      setState(() {
        _aiSummary = summary;
        _isLoadingSummary = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover Image
                Container(
                  height: 300,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1573348722427-f1d6819fdf98?q=80&w=800&auto=format&fit=crop'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Rating
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.listing.title,
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.grey, size: 16),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(widget.listing.address, style: TextStyle(color: Colors.grey[700])),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 20),
                                SizedBox(width: 4),
                                Text('4.8', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      
                      // Host Info
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hosted by Ahmed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('Joined 2023', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      
                      // Amenities
                      const Text('Amenities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (widget.listing.hasCctv) _buildAmenityChip(Icons.videocam, 'CCTV'),
                          if (widget.listing.isCovered) _buildAmenityChip(Icons.roofing, 'Covered'),
                          if (widget.listing.hasSecurity) _buildAmenityChip(Icons.security, 'Guard'),
                          if (widget.listing.hasEvCharging) _buildAmenityChip(Icons.electrical_services, 'EV Charging'),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Description
                      const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        widget.listing.description?.isNotEmpty == true 
                            ? widget.listing.description! 
                            : 'No description provided for this listing.',
                        style: TextStyle(color: Colors.grey[800], height: 1.5),
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // AI Review Summary
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                          const SizedBox(width: 8),
                          const Text('AI Review Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          child: Text(
                            _aiSummary!,
                            style: TextStyle(color: Colors.deepPurple.shade900, height: 1.5, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Sticky Bottom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Price', style: TextStyle(color: Colors.grey)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('৳${widget.listing.hourlyRate?.toInt() ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const Text('/hr', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.push('/rider/explore/checkout', extra: widget.listing);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Book Now', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityChip(IconData icon, String label) {
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
}
