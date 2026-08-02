import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../owner/data/models/listing_model.dart';
import '../../../../shared/data/repositories/bookings_repository.dart';
import '../controllers/bookings_controller.dart';
import '../controllers/vehicles_controller.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../wallet/presentation/controllers/wallet_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final ListingModel listing;

  const CheckoutScreen({super.key, required this.listing});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _durationCount = 1;
  String _durationType = 'Hourly'; // Hourly, Daily, Weekly, Monthly, Yearly
  final double _platformFee = 10.0;
  String _selectedPaymentMethod = 'wallet';
  String? _selectedVehicleId;

  // Pricing Logic
  double get _baseRate {
    switch (_durationType) {
      case 'Hourly': return widget.listing.hourlyRate ?? 0.0;
      case 'Daily': return widget.listing.dailyRate ?? ((widget.listing.hourlyRate ?? 0) * 12);
      case 'Weekly': return widget.listing.weeklyRate ?? ((widget.listing.dailyRate ?? 0) * 7);
      case 'Monthly': return widget.listing.monthlyRate ?? ((widget.listing.weeklyRate ?? 0) * 4);
      case 'Yearly': return widget.listing.yearlyRate ?? ((widget.listing.monthlyRate ?? 0) * 12);
      default: return 0.0;
    }
  }

  bool get _isPeakHour {
    final hour = DateTime.now().hour;
    // Peak hours: 8 AM to 10 AM, and 5 PM to 8 PM (17 to 20)
    return (hour >= 8 && hour <= 10) || (hour >= 17 && hour <= 20);
  }

  double get _peakMultiplier => _isPeakHour ? 1.5 : 1.0;
  double get _subtotal => _baseRate * _durationCount * _peakMultiplier;
  double get _totalPrice => _subtotal + _platformFee;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormatter = NumberFormat.currency(locale: 'bn_BD', symbol: '৳', decimalDigits: 0);
    String durationLabel(String t) => switch (t) {
          'Hourly' => l10n.hourly,
          'Daily' => l10n.daily,
          'Weekly' => l10n.weekly,
          'Monthly' => l10n.monthly,
          'Yearly' => l10n.yearly,
          _ => t,
        };

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(l10n.checkout, style: const TextStyle(fontWeight: FontWeight.bold)),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
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
                        const SizedBox(height: 8),
                        Text(l10n.availableSlotsLabel(widget.listing.availableSlots, widget.listing.totalSlots), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Duration Selection
            Text(l10n.selectDuration, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _durationType,
                        isExpanded: true,
                        items: ['Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly'].map((t) => DropdownMenuItem(value: t, child: Text(durationLabel(t)))).toList(),
                        onChanged: (val) => setState(() => _durationType = val!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    IconButton(onPressed: () { if (_durationCount > 1) setState(() => _durationCount--); }, icon: const Icon(Icons.remove_circle_outline, color: Colors.deepPurple)),
                    Text('$_durationCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => setState(() => _durationCount++), icon: const Icon(Icons.add_circle_outline, color: Colors.deepPurple)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Select Vehicle
            Text(l10n.selectVehicle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        label: Text(l10n.addVehicleFirst),
                      );
                    }
                    if (_selectedVehicleId == null && vehicles.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _selectedVehicleId = vehicles.first.id);
                      });
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedVehicleId,
                          isExpanded: true,
                          hint: Text(l10n.selectYourVehicle),
                          items: vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(v.displayName))).toList(),
                          onChanged: (value) => setState(() => _selectedVehicleId = value),
                        ),
                      ),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, st) => Text('${l10n.error}: $e'),
                );
              },
            ),
            const SizedBox(height: 32),

            // Payment Method
            Text(l10n.paymentMethod, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final walletStateAsync = ref.watch(walletControllerProvider);
                final balanceText = walletStateAsync.maybeWhen(data: (state) => '৳${state.balance.toStringAsFixed(2)}', orElse: () => '...');
                return _buildPaymentOption('wallet', l10n.walletBalanceOption(balanceText), Icons.account_balance_wallet);
              }
            ),
            const SizedBox(height: 12),
            _buildPaymentOption('sslcommerz', l10n.onlinePaymentSsl, Icons.credit_card),

            const SizedBox(height: 32),

            // Price Breakdown
            Text(l10n.priceBreakdown, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.deepPurple.shade100)),
              child: Column(
                children: [
                  _buildPriceRow(l10n.baseRateLabel(durationLabel(_durationType)), currencyFormatter.format(_baseRate)),
                  _buildPriceRow(l10n.duration, 'x $_durationCount'),
                  if (_isPeakHour) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text(l10n.peakHourApplied, style: const TextStyle(color: Colors.orange, fontSize: 12)),
                          ],
                        ),
                        const Text('x 1.5', style: TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildPriceRow(l10n.platformFee, currencyFormatter.format(_platformFee)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.totalAmount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(currencyFormatter.format(_totalPrice), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.serverPricesFinal,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Confirm Button
            ElevatedButton(
              onPressed: () async {
                if (_selectedVehicleId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.selectVehicleFirst)));
                  return;
                }

                // Vehicle Compatibility Check
                final vehicles = ref.read(vehiclesControllerProvider).value ?? [];
                final matches = vehicles.where((v) => v.id == _selectedVehicleId);
                if (matches.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.selectValidVehicle)));
                  return;
                }
                final selectedVehicle = matches.first;

                // Ensure vehicle type is allowed by this listing
                if (!widget.listing.allowedVehicleTypes.contains(selectedVehicle.type)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.vehicleNotAllowed(selectedVehicle.type))),
                  );
                  return;
                }

                if (widget.listing.availableSlots <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noSlotsAvailable)));
                  return;
                }

                if (_selectedPaymentMethod != 'wallet') {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.sslUnderConstruction)));
                  return;
                }

                final user = ref.read(authStateChangesProvider).value?.session?.user;
                if (user == null) return;

                final req = BookingRequest(
                  riderId: user.id,
                  listingId: widget.listing.id!,
                  vehicleId: _selectedVehicleId!,
                  vehicleType: selectedVehicle.type,
                  durationType: _durationType,
                  durationCount: _durationCount,
                  startTime: DateTime.now(),
                );

                final messenger = ScaffoldMessenger.of(context);
                final router = GoRouter.of(context);
                try {
                  await ref.read(bookingsControllerProvider.notifier).createBooking(req);
                  ref.invalidate(walletControllerProvider);

                  messenger.showSnackBar(SnackBar(content: Text(l10n.bookingConfirmed)));
                  router.push('/rider/explore/active');
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim())));
                }
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l10n.payAmount(currencyFormatter.format(_totalPrice)), style: const TextStyle(fontSize: 18)),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _selectedPaymentMethod == value ? Colors.deepPurple : Colors.grey.shade300, width: _selectedPaymentMethod == value ? 2 : 1)),
        child: Row(
          children: [
            Icon(icon, color: _selectedPaymentMethod == value ? Colors.deepPurple : Colors.grey),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
            Icon(
              _selectedPaymentMethod == value ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: _selectedPaymentMethod == value ? Colors.deepPurple : Colors.grey,
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
