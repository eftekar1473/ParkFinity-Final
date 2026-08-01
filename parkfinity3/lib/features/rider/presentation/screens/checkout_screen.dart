import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../owner/data/models/listing_model.dart';
import '../../../../shared/data/models/booking_model.dart';
import '../controllers/bookings_controller.dart';
import '../controllers/vehicles_controller.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../wallet/presentation/controllers/wallet_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final ListingModel listing;

  const CheckoutScreen({super.key, required this.listing});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _selectedHours = 2;
  final double _platformFee = 10.0;
  String _selectedPaymentMethod = 'wallet';
  String? _selectedVehicleId;

  double get _hourlyRate => widget.listing.hourlyRate ?? 0.0;
  double get _totalPrice => (_hourlyRate * _selectedHours) + _platformFee;

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'bn_BD', symbol: '৳', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_parking, size: 40, color: Colors.deepPurple),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.listing.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(widget.listing.address, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Duration Selection
            const Text('Select Duration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    if (_selectedHours > 1) setState(() => _selectedHours--);
                  },
                  icon: const Icon(Icons.remove_circle_outline, size: 32, color: Colors.deepPurple),
                ),
                const SizedBox(width: 24),
                Text('$_selectedHours Hours', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: () => setState(() => _selectedHours++),
                  icon: const Icon(Icons.add_circle_outline, size: 32, color: Colors.deepPurple),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Select Vehicle
            const Text('Select Vehicle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final vehiclesAsync = ref.watch(vehiclesControllerProvider);
                return vehiclesAsync.when(
                  data: (vehicles) {
                    if (vehicles.isEmpty) {
                      return ElevatedButton.icon(
                        onPressed: () => context.push('/rider/profile/vehicles'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add a Vehicle First'),
                      );
                    }

                    // Select the first vehicle by default if not set
                    if (_selectedVehicleId == null && vehicles.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _selectedVehicleId = vehicles.first.id);
                      });
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedVehicleId,
                          isExpanded: true,
                          hint: const Text('Select your vehicle'),
                          items: vehicles.map((v) {
                            return DropdownMenuItem(
                              value: v.id,
                              child: Text(v.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedVehicleId = value);
                          },
                        ),
                      ),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, st) => Text('Error: $e'),
                );
              },
            ),
            const SizedBox(height: 32),

            // Payment Method
            const Text('Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final walletStateAsync = ref.watch(walletControllerProvider);
                final balanceText = walletStateAsync.maybeWhen(
                  data: (state) => '৳${state.balance.toStringAsFixed(2)}',
                  orElse: () => '...',
                );
                return _buildPaymentOption('wallet', 'ParkFinity Wallet (Bal: $balanceText)', Icons.account_balance_wallet);
              }
            ),
            const SizedBox(height: 12),
            _buildPaymentOption('sslcommerz', 'Online Payment (SSLCommerz)', Icons.credit_card),
            
            const SizedBox(height: 32),

            // Price Breakdown
            const Text('Price Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurple.shade100),
              ),
              child: Column(
                children: [
                  _buildPriceRow('Parking Fee (${currencyFormatter.format(_hourlyRate)} x $_selectedHours)', currencyFormatter.format(_hourlyRate * _selectedHours)),
                  const SizedBox(height: 8),
                  _buildPriceRow('Platform Fee', currencyFormatter.format(_platformFee)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(currencyFormatter.format(_totalPrice), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Confirm Button
            ElevatedButton(
              onPressed: () async {
                if (_selectedVehicleId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please add and select a vehicle first.')),
                  );
                  return;
                }

                if (_selectedPaymentMethod != 'wallet') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Direct SSLCommerz checkout is under construction. Please use your Wallet!')),
                  );
                  return;
                }

                final user = ref.read(authStateChangesProvider).value?.session?.user;
                if (user == null) return;
                
                final now = DateTime.now();
                final booking = BookingModel(
                  riderId: user.id,
                  listingId: widget.listing.id!,
                  startTime: now,
                  endTime: now.add(Duration(hours: _selectedHours)),
                  totalAmount: _totalPrice,
                  commissionAmount: _platformFee,
                  ownerEarnings: _totalPrice - _platformFee,
                );

                try {
                  await ref.read(bookingsControllerProvider.notifier).createBooking(booking);
                  // Refresh wallet balance
                  ref.refresh(walletControllerProvider.future);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Booking confirmed!')),
                    );
                    context.push('/rider/explore/active');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim())),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Pay ${currencyFormatter.format(_totalPrice)}', style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String value, String title, IconData icon) {
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedPaymentMethod == value ? Colors.deepPurple : Colors.grey.shade300,
            width: _selectedPaymentMethod == value ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: _selectedPaymentMethod == value ? Colors.deepPurple : Colors.grey),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
            Radio<String>(
              value: value,
              groupValue: _selectedPaymentMethod,
              activeColor: Colors.deepPurple,
              onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700])),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
