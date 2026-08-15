import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sslcommerz/model/SSLCCustomerInfoInitializer.dart';
import 'package:flutter_sslcommerz/model/SSLCEMITransactionInitializer.dart';
import 'package:flutter_sslcommerz/model/SSLCSdkType.dart';
import 'package:flutter_sslcommerz/model/SSLCTransactionInfoModel.dart';
import 'package:flutter_sslcommerz/model/SSLCommerzInitialization.dart';
import 'package:flutter_sslcommerz/model/SSLCurrencyType.dart';
import 'package:flutter_sslcommerz/sslcommerz.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../owner/data/models/listing_model.dart';
import '../../../../shared/data/repositories/bookings_repository.dart';
import '../../../parking/data/availability_repository.dart';
import '../controllers/bookings_controller.dart';
import '../controllers/vehicles_controller.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../shared/data/my_profile_repository.dart';
import '../../../wallet/presentation/controllers/wallet_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Duration unit lengths, mirrored from the create-booking Edge Function so the
/// end time shown to the rider matches what the server will store.
const _unitMinutes = {
  'Hourly': 60,
  'Daily': 1440,
  'Weekly': 10080,
  'Monthly': 43200,
  'Yearly': 525600,
};

class CheckoutScreen extends ConsumerStatefulWidget {
  final ListingModel listing;

  const CheckoutScreen({super.key, required this.listing});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _durationCount = 1;
  String _durationType = 'Hourly';
  final double _platformFee = 10.0;
  String _selectedPaymentMethod = 'wallet';
  String? _selectedVehicleId;
  bool _submitting = false;

  /// Rider-chosen start. Defaults to the next 5-minute mark so the picker never
  /// opens on a time that is already in the past.
  late DateTime _startTime = _roundUp(DateTime.now());

  static DateTime _roundUp(DateTime t) {
    final add = (5 - t.minute % 5) % 5;
    return DateTime(t.year, t.month, t.day, t.hour, t.minute + add);
  }

  DateTime get _endTime => _startTime
      .add(Duration(minutes: _unitMinutes[_durationType]! * _durationCount));

  double get _baseRate {
    switch (_durationType) {
      case 'Hourly':
        return widget.listing.hourlyRate ?? 0.0;
      case 'Daily':
        return widget.listing.dailyRate ??
            ((widget.listing.hourlyRate ?? 0) * 12);
      case 'Weekly':
        return widget.listing.weeklyRate ??
            ((widget.listing.dailyRate ?? 0) * 7);
      case 'Monthly':
        return widget.listing.monthlyRate ??
            ((widget.listing.weeklyRate ?? 0) * 4);
      case 'Yearly':
        return widget.listing.yearlyRate ??
            ((widget.listing.monthlyRate ?? 0) * 12);
      default:
        return 0.0;
    }
  }

  /// Peak is judged on the chosen start hour, not on "now" — booking an 8am slot
  /// at midnight still has to price as peak.
  bool get _isPeakHour {
    final hour = _startTime.hour;
    return (hour >= 8 && hour <= 10) || (hour >= 17 && hour <= 20);
  }

  double get _peakMultiplier => _isPeakHour ? 1.5 : 1.0;
  double get _subtotal => _baseRate * _durationCount * _peakMultiplier;
  double get _totalPrice => _subtotal + _platformFee;

  /// Vehicle type currently selected, needed to ask the server about the right
  /// slot pool. Null until vehicles load.
  String? get _selectedVehicleType {
    final vehicles = ref.read(vehiclesControllerProvider).value ?? [];
    final m = vehicles.where((v) => v.id == _selectedVehicleId);
    return m.isEmpty ? null : m.first.type;
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime.isBefore(now) ? now : _startTime,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _startTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currencyFormatter =
        NumberFormat.currency(locale: 'bn_BD', symbol: '৳', decimalDigits: 0);
    final stamp = DateFormat('EEE d MMM, h:mm a');

    String durationLabel(String t) => switch (t) {
          'Hourly' => l10n.hourly,
          'Daily' => l10n.daily,
          'Weekly' => l10n.weekly,
          'Monthly' => l10n.monthly,
          'Yearly' => l10n.yearly,
          _ => t,
        };

    final vtype = _selectedVehicleType;
    final availAsync = vtype == null
        ? null
        : ref.watch(availableQtyProvider(AvailabilityQuery(
            listingId: widget.listing.id!,
            vehicleType: vtype,
            start: _startTime,
            end: _endTime,
          )));
    final avail = availAsync?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.checkout,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Spot summary
            _Card(
              child: Row(
                children: [
                  Icon(Icons.local_parking,
                      size: 40, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.listing.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(widget.listing.address,
                            style: TextStyle(color: theme.hintColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Start / end window
            Text(l10n.startTime,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickStart,
              icon: const Icon(Icons.schedule),
              label: Text(stamp.format(_startTime)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.arrow_forward, size: 16, color: theme.hintColor),
                const SizedBox(width: 8),
                Text('${l10n.endTime}: ${stamp.format(_endTime)}',
                    style: TextStyle(color: theme.hintColor)),
              ],
            ),
            const SizedBox(height: 32),

            // Duration
            Text(l10n.selectDuration,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _durationType,
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                    items: _unitMinutes.keys
                        .map((t) => DropdownMenuItem(
                            value: t, child: Text(durationLabel(t))))
                        .toList(),
                    onChanged: (val) => setState(() => _durationType = val!),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    if (_durationCount > 1) setState(() => _durationCount--);
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_durationCount',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => _durationCount++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live availability for this exact window
            if (availAsync != null)
              availAsync.when(
                loading: () => Row(
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text(l10n.loadingLabel,
                        style: TextStyle(color: theme.hintColor)),
                  ],
                ),
                error: (e, _) => Text(l10n.somethingWentWrong,
                    style: TextStyle(color: theme.colorScheme.error)),
                data: (qty) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (qty > 0 ? Colors.green : theme.colorScheme.error)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(qty > 0 ? Icons.check_circle : Icons.block,
                          color:
                              qty > 0 ? Colors.green : theme.colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(qty > 0
                            ? l10n.availableSlotsLabel(
                                qty, widget.listing.slotCapacity[vtype] ?? qty)
                            : l10n.noSlotsAvailable),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),

            // Vehicle
            Text(l10n.selectVehicle,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final vehiclesAsync = ref.watch(vehiclesControllerProvider);
                return vehiclesAsync.when(
                  data: (vehicles) {
                    if (vehicles.isEmpty) {
                      return ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/rider/profile/vehicles'),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addVehicleFirst),
                      );
                    }
                    if (_selectedVehicleId == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(
                              () => _selectedVehicleId = vehicles.first.id);
                        }
                      });
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedVehicleId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.selectYourVehicle,
                        border: const OutlineInputBorder(),
                      ),
                      items: vehicles.map((v) {
                        final isAllowed =
                            widget.listing.allowedVehicleTypes.contains(v.type);
                        return DropdownMenuItem(
                          value: v.id,
                          enabled: isAllowed,
                          child: Text(
                            '${v.model} (${v.licensePlate}) - ${v.type}${isAllowed ? '' : ' (${l10n.vehicleNotAllowed(v.type)})'}',
                            style: TextStyle(
                              color: isAllowed ? null : theme.disabledColor,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedVehicleId = val),
                    );
                  },
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, _) => Text(l10n.somethingWentWrong,
                      style: TextStyle(color: theme.colorScheme.error)),
                );
              },
            ),
            const SizedBox(height: 32),

            // Payment
            Text(l10n.paymentMethod,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Consumer(builder: (context, ref, _) {
              final walletStateAsync = ref.watch(walletControllerProvider);
              final balanceText = walletStateAsync.maybeWhen(
                  data: (state) => '৳${state.balance.toStringAsFixed(2)}',
                  orElse: () => '...');
              return _buildPaymentOption(
                  'wallet',
                  l10n.walletBalanceOption(balanceText),
                  Icons.account_balance_wallet);
            }),
            const SizedBox(height: 12),
            _buildPaymentOption(
                'sslcommerz', l10n.onlinePaymentSsl, Icons.credit_card),
            const SizedBox(height: 32),

            // Breakdown
            Text(l10n.priceBreakdown,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                children: [
                  _buildPriceRow(
                      l10n.baseRateLabel(durationLabel(_durationType)),
                      currencyFormatter.format(_baseRate)),
                  _buildPriceRow(l10n.duration, 'x $_durationCount'),
                  if (_isPeakHour) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text(l10n.peakHourApplied,
                                style: const TextStyle(
                                    color: Colors.orange, fontSize: 12)),
                          ],
                        ),
                        const Text('x 1.5',
                            style: TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildPriceRow(l10n.platformFee,
                      currencyFormatter.format(_platformFee)),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider()),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.totalAmount,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(currencyFormatter.format(_totalPrice),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.serverPricesFinal,
                      style: TextStyle(color: theme.hintColor, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: (_submitting || avail == 0) ? null : _confirm,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      l10n.payAmount(currencyFormatter.format(_totalPrice)),
                      style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    if (_selectedVehicleId == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.selectVehicleFirst)));
      return;
    }

    final vehicles = ref.read(vehiclesControllerProvider).value ?? [];
    final matches = vehicles.where((v) => v.id == _selectedVehicleId);
    if (matches.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.selectValidVehicle)));
      return;
    }
    final selectedVehicle = matches.first;

    if (!widget.listing.allowedVehicleTypes.contains(selectedVehicle.type)) {
      messenger.showSnackBar(SnackBar(
          content: Text(l10n.vehicleNotAllowed(selectedVehicle.type))));
      return;
    }

    if (_startTime.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.pickStartTime)));
      return;
    }

    final user = ref.read(authStateChangesProvider).value?.session?.user;
    if (user == null) return;

    if (_selectedPaymentMethod == 'sslcommerz') {
      setState(() => _submitting = true);
      try {
        final profile = ref.read(currentProfileProvider).value;
        final storeId = dotenv.env['SSLCOMMERZ_STORE_ID'] ?? 'your_store_id';
        final storePass =
            dotenv.env['SSLCOMMERZ_STORE_PASSWD'] ?? 'your_store_passwd';
        final txnId = "BOOKING_${DateTime.now().millisecondsSinceEpoch}";

        final sslcommerz = Sslcommerz(
          initializer: SSLCommerzInitialization(
            multi_card_name: 'internetbank',
            currency: SSLCurrencyType.BDT,
            product_category: 'ParkingBooking',
            sdkType: SSLCSdkType.TESTBOX,
            store_id: storeId,
            store_passwd: storePass,
            total_amount: _totalPrice,
            tran_id: txnId,
          ),
        );

        sslcommerz.addCustomerInfoInitializer(
          customerInfoInitializer: SSLCCustomerInfoInitializer(
            customerName: profile?.fullName ?? 'Parkfinity User',
            customerEmail: profile?.email ?? 'user@parkfinity.com',
            customerAddress1: 'Dhaka',
            customerCity: 'Dhaka',
            customerState: 'Dhaka',
            customerPostCode: '1000',
            customerCountry: 'Bangladesh',
            customerPhone: profile?.phoneNumber ?? '01700000000',
          ),
        );

        sslcommerz.addEMITransactionInitializer(
            sslcemiTransactionInitializer:
                SSLCEMITransactionInitializer(emi_options: 0));

        final SSLCTransactionInfoModel result = await sslcommerz.payNow();
        if (!mounted) return;
        final status = result.status?.toUpperCase();

        if (status == 'VALID' || status == 'VALIDATED') {
          final valId = result.valId;
          final credited = valId == null
              ? false
              : await ref
                  .read(walletControllerProvider.notifier)
                  .creditTopUp(valId);
          if (!credited) {
            messenger.showSnackBar(SnackBar(content: Text(l10n.paymentFailed)));
            return;
          }
          ref.invalidate(currentProfileProvider);
          ref.invalidate(walletControllerProvider);
        } else if (status == 'FAILED') {
          messenger.showSnackBar(SnackBar(content: Text(l10n.paymentFailed)));
          return;
        } else {
          messenger.showSnackBar(SnackBar(content: Text(l10n.paymentCancelled)));
          return;
        }
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('${l10n.paymentError}: $e')));
        return;
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }

    setState(() => _submitting = true);
    try {
      await ref.read(bookingsControllerProvider.notifier).createBooking(
            BookingRequest(
              riderId: user.id,
              listingId: widget.listing.id!,
              vehicleId: _selectedVehicleId!,
              vehicleType: selectedVehicle.type,
              durationType: _durationType,
              durationCount: _durationCount,
              startTime: _startTime,
            ),
          );
      ref.invalidate(walletControllerProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.bookingConfirmed)));
      router.push('/active_session');
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildPaymentOption(String value, String title, IconData icon) {
    final theme = Theme.of(context);
    final selected = _selectedPaymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? theme.colorScheme.primary : theme.hintColor),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? theme.colorScheme.primary : theme.hintColor,
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
        Text(label, style: TextStyle(color: Theme.of(context).hintColor)),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

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
      child: child,
    );
  }
}
