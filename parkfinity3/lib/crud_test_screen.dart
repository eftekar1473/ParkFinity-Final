import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CrudTestScreen extends StatefulWidget {
  const CrudTestScreen({super.key});

  @override
  State<CrudTestScreen> createState() => _CrudTestScreenState();
}

class _CrudTestScreenState extends State<CrudTestScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = false;

  // Since profiles don't auto-generate UUIDs (they expect Firebase UID), 
  // we'll test CRUD on 'vehicles' which has a default gen_random_uuid().
  // However, vehicles require an 'owner_id'. 
  // For this test, we'll use a dummy UUID for the owner.
  final String _dummyOwnerId = '00000000-0000-0000-0000-000000000000';

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  Future<void> _ensureDummyProfile() async {
    // Check if dummy profile exists to satisfy foreign key constraints
    final res = await _supabase.from('profiles').select('id').eq('id', _dummyOwnerId).maybeSingle();
    if (res == null) {
      await _supabase.from('profiles').insert({
        'id': _dummyOwnerId,
        'email': 'test@crud.com',
        'full_name': 'CRUD Tester',
      });
    }
  }

  Future<void> _fetchVehicles() async {
    setState(() => _isLoading = true);
    try {
      await _ensureDummyProfile();
      final data = await _supabase.from('vehicles').select();
      setState(() {
        _vehicles = List<Map<String, dynamic>>.from(data);
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fetch error: $error')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _insertVehicle() async {
    setState(() => _isLoading = true);
    try {
      await _ensureDummyProfile();
      final randomNum = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      await _supabase.from('vehicles').insert({
        'owner_id': _dummyOwnerId,
        'type': 'Car',
        'brand': 'Toyota',
        'model': 'Corolla',
        'license_plate': 'DHA-KHA-$randomNum',
        'color': 'Black',
      });
      await _fetchVehicles();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Insert error: $error')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteVehicle(String id) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('vehicles').delete().eq('id', id);
      await _fetchVehicles();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $error')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase CRUD Test'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? const Center(child: Text('No vehicles found. Press + to add.'))
              : ListView.builder(
                  itemCount: _vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = _vehicles[index];
                    return ListTile(
                      title: Text('${vehicle['brand']} ${vehicle['model']}'),
                      subtitle: Text('Plate: ${vehicle['license_plate']} | Type: ${vehicle['type']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteVehicle(vehicle['id']),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _insertVehicle,
        child: const Icon(Icons.add),
      ),
    );
  }
}
