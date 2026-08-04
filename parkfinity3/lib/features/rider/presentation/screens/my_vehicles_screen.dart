import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/vehicles_controller.dart';
import '../../data/models/vehicle_model.dart';
import '../../../../l10n/generated/app_localizations.dart';

class MyVehiclesScreen extends ConsumerStatefulWidget {
  const MyVehiclesScreen({super.key});

  @override
  ConsumerState<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends ConsumerState<MyVehiclesScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'Car';
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();

  final List<String> _vehicleTypes = [
    'Bicycle', 'Motorcycle', 'Car', 'Rickshaw', 
    'Auto', 'CNG', 'SUV', 'Microbus', 'Pickup', 'EV', 'Other'
  ];

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  void _showAddVehicleBottomSheet(BuildContext context) {
    _brandController.clear();
    _modelController.clear();
    _plateController.clear();
    setState(() => _selectedType = 'Car');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final l10n = AppLocalizations.of(context);
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.addNewVehicle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: InputDecoration(
                      labelText: l10n.vehicleType,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: _vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      setModalState(() => _selectedType = val!);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _brandController,
                    decoration: InputDecoration(
                      labelText: l10n.brand,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.business),
                    ),
                    validator: (v) => v!.isEmpty ? l10n.required : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: l10n.model,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.directions_car),
                    ),
                    validator: (v) => v!.isEmpty ? l10n.required : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _plateController,
                    decoration: InputDecoration(
                      labelText: l10n.licensePlate,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.pin),
                    ),
                    validator: (v) => v!.isEmpty ? l10n.required : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          await ref.read(vehiclesControllerProvider.notifier).addVehicle(
                            _selectedType,
                            _brandController.text.trim(),
                            _modelController.text.trim(),
                            _plateController.text.trim(),
                          );
                          if (context.mounted) {
                            context.pop();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.vehicleAdded)));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: Text(l10n.saveVehicle, style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  void _deleteVehicle(VehicleModel vehicle) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteVehicle),
        content: Text(l10n.deleteVehicleConfirm(vehicle.displayName)),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () async {
              ctx.pop();
              try {
                await ref.read(vehiclesControllerProvider.notifier).deleteVehicle(vehicle.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.vehicleDeleted)));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
                }
              }
            },
            child: Text(l10n.delete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehiclesAsync = ref.watch(vehiclesControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.myVehicles, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        elevation: 0,
      ),
      body: vehiclesAsync.when(
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return Center(child: Text(l10n.noVehicles));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vehiclesControllerProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(24.0),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final v = vehicles[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildVehicleCard(
                    vehicle: v,
                    isDefault: index == 0,
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('${l10n.error}: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVehicleBottomSheet(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: Icon(Icons.add, color: Theme.of(context).colorScheme.surfaceContainerLow),
        label: Text(l10n.addVehicle, style: TextStyle(color: Theme.of(context).colorScheme.surfaceContainerLow)),
      ),
    );
  }

  Widget _buildVehicleCard({required VehicleModel vehicle, required bool isDefault}) {
    IconData getVehicleIcon(String type) {
      switch (type) {
        case 'Motorcycle':
          return Icons.two_wheeler;
        case 'Bicycle':
          return Icons.pedal_bike;
        case 'SUV':
        case 'Microbus':
        case 'Pickup':
          return Icons.directions_bus;
        case 'Car':
        default:
          return Icons.directions_car;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDefault ? Theme.of(context).colorScheme.primary : Theme.of(context).hintColor, width: isDefault ? 2 : 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(getVehicleIcon(vehicle.type), color: Theme.of(context).colorScheme.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${vehicle.brand} ${vehicle.model}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(vehicle.licensePlate, style: TextStyle(color: Theme.of(context).hintColor, letterSpacing: 1.2)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
            onPressed: () => _deleteVehicle(vehicle),
          ),
        ],
      ),
    );
  }
}
