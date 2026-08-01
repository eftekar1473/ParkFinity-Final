class ListingModel {
  final String? id;
  final String ownerId;
  final String title;
  final String? description;
  final String address;
  final double latitude;
  final double longitude;
  final bool isCovered;
  final bool hasSecurity;
  final bool hasCctv;
  final bool hasEvCharging;
  final List<String> allowedVehicleTypes;
  final double? hourlyRate;
  final double? dailyRate;
  final double? weeklyRate;
  final double? monthlyRate;
  final bool instantBooking;
  final bool isActive;
  final List<String> photos;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ListingModel({
    this.id,
    required this.ownerId,
    required this.title,
    this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.isCovered = false,
    this.hasSecurity = false,
    this.hasCctv = false,
    this.hasEvCharging = false,
    required this.allowedVehicleTypes,
    this.hourlyRate,
    this.dailyRate,
    this.weeklyRate,
    this.monthlyRate,
    this.instantBooking = true,
    this.isActive = true,
    this.photos = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    return ListingModel(
      id: json['id'] as String?,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      address: json['address'] as String,
      // Parse decimal/numeric correctly
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isCovered: json['is_covered'] as bool? ?? false,
      hasSecurity: json['has_security'] as bool? ?? false,
      hasCctv: json['has_cctv'] as bool? ?? false,
      hasEvCharging: json['has_ev_charging'] as bool? ?? false,
      allowedVehicleTypes: (json['allowed_vehicle_types'] as List?)?.map((e) => e.toString()).toList() ?? [],
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
      dailyRate: (json['daily_rate'] as num?)?.toDouble(),
      weeklyRate: (json['weekly_rate'] as num?)?.toDouble(),
      monthlyRate: (json['monthly_rate'] as num?)?.toDouble(),
      instantBooking: json['instant_booking'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      photos: (json['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'owner_id': ownerId,
      'title': title,
      if (description != null) 'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'is_covered': isCovered,
      'has_security': hasSecurity,
      'has_cctv': hasCctv,
      'has_ev_charging': hasEvCharging,
      'allowed_vehicle_types': allowedVehicleTypes,
      if (hourlyRate != null) 'hourly_rate': hourlyRate,
      if (dailyRate != null) 'daily_rate': dailyRate,
      if (weeklyRate != null) 'weekly_rate': weeklyRate,
      if (monthlyRate != null) 'monthly_rate': monthlyRate,
      'instant_booking': instantBooking,
      'is_active': isActive,
      'photos': photos,
    };
  }
}
