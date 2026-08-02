import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/listings_controller.dart';
import '../../data/models/listing_model.dart';
import '../../../../l10n/generated/app_localizations.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final listingsAsync = ref.watch(myListingsProvider);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(l10n.myListings, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: listingsAsync.when(
        data: (listings) {
          if (listings.isEmpty) {
            return Center(child: Text(l10n.noListings));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: listings.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final listing = listings[index];
              return _ListingCard(
                listing: listing,
                onDelete: () {
                  ref.read(myListingsProvider.notifier).deleteListing(listing.id!);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${l10n.error}: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/add_listing');
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ListingCard extends ConsumerStatefulWidget {
  final ListingModel listing;
  final VoidCallback onDelete;

  const _ListingCard({
    required this.listing,
    required this.onDelete,
  });

  @override
  ConsumerState<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends ConsumerState<_ListingCard> {
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _isActive = widget.listing.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cover image (first listing photo; placeholder if none)
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              image: widget.listing.photos.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(widget.listing.photos.first),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.listing.photos.isEmpty
                ? const Center(
                    child: Icon(Icons.local_parking, size: 40, color: Colors.white))
                : null,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.listing.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '৳${widget.listing.hourlyRate?.toInt() ?? 0}/hr',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      widget.listing.address,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.listing.slotCapacity.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.listing.slotCapacity.entries.map((e) {
                      final avail = widget.listing.slotAvailable[e.key] ?? e.value;
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${e.key}: $avail/${e.value}',
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: avail > 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isActive ? Icons.check_circle : Icons.pause_circle_filled,
                          color: _isActive ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isActive ? l10n.statusActive : l10n.paused,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isActive ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Switch(
                          value: _isActive,
                          activeThumbColor: Colors.green,
                          onChanged: (value) async {
                            final previousValue = _isActive;
                            setState(() {
                              _isActive = value;
                            });
                            try {
                              await ref.read(myListingsProvider.notifier).updateListingStatus(widget.listing.id!, value);
                            } catch (e) {
                              setState(() {
                                _isActive = previousValue; // Revert on failure
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.failedUpdateStatus('$e'))),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.deepPurple),
                          onPressed: () => context
                              .push('/edit_listing', extra: widget.listing),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: widget.onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
