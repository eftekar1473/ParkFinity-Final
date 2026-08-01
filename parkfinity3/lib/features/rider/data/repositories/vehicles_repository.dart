import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle_model.dart';

final vehiclesRepositoryProvider = Provider<VehiclesRepository>((ref) {
  return VehiclesRepository(Supabase.instance.client);
});

class VehiclesRepository {
  final SupabaseClient _client;

  VehiclesRepository(this._client);

  Future<List<VehicleModel>> getVehicles(String riderId) async {
    final response = await _client
        .from('vehicles')
        .select()
        .eq('owner_id', riderId)
        .order('created_at', ascending: false);
        
    return (response as List).map((e) => VehicleModel.fromJson(e)).toList();
  }

  Future<VehicleModel> addVehicle(VehicleModel vehicle) async {
    final response = await _client
        .from('vehicles')
        .insert(vehicle.toJson())
        .select()
        .single();
        
    return VehicleModel.fromJson(response);
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await _client.from('vehicles').delete().eq('id', vehicleId);
  }
}
