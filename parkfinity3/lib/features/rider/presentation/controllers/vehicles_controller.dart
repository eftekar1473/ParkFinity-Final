import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/vehicle_model.dart';
import '../../data/repositories/vehicles_repository.dart';

final vehiclesControllerProvider = AsyncNotifierProvider<VehiclesController, List<VehicleModel>>(() {
  return VehiclesController();
});

class VehiclesController extends AsyncNotifier<List<VehicleModel>> {
  @override
  Future<List<VehicleModel>> build() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    
    final repository = ref.read(vehiclesRepositoryProvider);
    return repository.getVehicles(userId);
  }

  Future<void> addVehicle(String type, String brand, String model, String licensePlate) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final repository = ref.read(vehiclesRepositoryProvider);
    
    final newVehicle = VehicleModel(
      ownerId: userId,
      type: type,
      brand: brand,
      model: model,
      licensePlate: licensePlate,
    );

    // Optimistic UI update could go here, or just fetch again.
    // For simplicity, we invalidate the provider.
    await repository.addVehicle(newVehicle);
    ref.invalidateSelf();
  }

  Future<void> deleteVehicle(String vehicleId) async {
    final repository = ref.read(vehiclesRepositoryProvider);
    await repository.deleteVehicle(vehicleId);
    ref.invalidateSelf();
  }
}
