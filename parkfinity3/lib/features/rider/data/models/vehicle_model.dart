class VehicleModel {
  final String? id;
  final String ownerId; // this is the rider's profile id
  final String type; // 'Car', 'Motorcycle', etc.
  final String brand;
  final String model;
  final String licensePlate;
  final String? color;
  final DateTime? createdAt;

  VehicleModel({
    this.id,
    required this.ownerId,
    required this.type,
    required this.brand,
    required this.model,
    required this.licensePlate,
    this.color,
    this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'],
      ownerId: json['owner_id'],
      type: json['type'],
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      licensePlate: json['license_plate'],
      color: json['color'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'owner_id': ownerId,
      'type': type,
      'brand': brand,
      'model': model,
      'license_plate': licensePlate,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
    };
  }

  String get displayName => '$brand $model ($licensePlate)';
}
