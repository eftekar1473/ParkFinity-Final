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
  final double? yearlyRate;

  /// Per-vehicle-type slot maps (source of truth). e.g. {"Car":10,"Motorcycle":5}
  final Map<String, int> slotCapacity;
  final Map<String, int> slotAvailable;

  /// Weekly open/close schedule (nullable = always open). Free-form JSON.
  final Map<String, dynamic>? availabilitySchedule;

  /// 'instant' | 'manual'
  final String bookingMode;

  final bool isActive;
  final bool isSuspended;
  final List<String> photos;
  final String? videoUrl;

  /// Server-generated QR identity for the printed poster. Read-only: never sent
  /// back in toJson so an update can't overwrite or rotate it by accident.
  final String? qrToken;
  final String? qrShortCode;

  /// Number riders can call about this spot. Falls back to the owner's profile
  /// phone when null.
  final String? contactPhone;

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
    this.yearlyRate,
    this.slotCapacity = const {},
    this.slotAvailable = const {},
    this.availabilitySchedule,
    this.bookingMode = 'instant',
    this.isActive = true,
    this.isSuspended = false,
    this.photos = const [],
    this.videoUrl,
    this.qrToken,
    this.qrShortCode,
    this.contactPhone,
    this.createdAt,
    this.updatedAt,
  });

  /// Sum of all per-type capacity (display convenience).
  int get totalSlots =>
      slotCapacity.values.fold(0, (a, b) => a + b);

  /// Sum of all per-type available (display convenience).
  int get availableSlots =>
      slotAvailable.values.fold(0, (a, b) => a + b);

  bool get instantBooking => bookingMode == 'instant';

  static Map<String, int> _parseSlotMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) =>
          MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    }
    return {};
  }

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    final cap = _parseSlotMap(json['slot_capacity']);
    final avail = _parseSlotMap(json['slot_available']);
    return ListingModel(
      id: json['id'] as String?,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isCovered: json['is_covered'] as bool? ?? false,
      hasSecurity: json['has_security'] as bool? ?? false,
      hasCctv: json['has_cctv'] as bool? ?? false,
      hasEvCharging: json['has_ev_charging'] as bool? ?? false,
      allowedVehicleTypes: (json['allowed_vehicle_types'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
      dailyRate: (json['daily_rate'] as num?)?.toDouble(),
      weeklyRate: (json['weekly_rate'] as num?)?.toDouble(),
      monthlyRate: (json['monthly_rate'] as num?)?.toDouble(),
      yearlyRate: (json['yearly_rate'] as num?)?.toDouble(),
      slotCapacity: cap,
      slotAvailable: avail.isEmpty ? cap : avail,
      availabilitySchedule: json['availability_schedule'] as Map<String, dynamic>?,
      bookingMode: (json['booking_mode'] as String?) ??
          ((json['instant_booking'] as bool? ?? true) ? 'instant' : 'manual'),
      isActive: json['is_active'] as bool? ?? true,
      isSuspended: json['is_suspended'] as bool? ?? false,
      photos: (json['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      videoUrl: json['video_url'] as String?,
      qrToken: json['qr_token'] as String?,
      qrShortCode: json['qr_short_code'] as String?,
      contactPhone: json['contact_phone'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
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
      if (yearlyRate != null) 'yearly_rate': yearlyRate,
      'slot_capacity': slotCapacity,
      'slot_available': slotAvailable,
      // Keep legacy scalar columns in sync for older code paths.
      'total_slots': totalSlots,
      'available_slots': availableSlots,
      if (availabilitySchedule != null)
        'availability_schedule': availabilitySchedule,
      'booking_mode': bookingMode,
      'instant_booking': instantBooking,
      'is_active': isActive,
      'is_suspended': isSuspended,
      'photos': photos,
      if (videoUrl != null) 'video_url': videoUrl,
      if (contactPhone != null) 'contact_phone': contactPhone,
    };
  }

  ListingModel copyWith({
    String? title,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    bool? isCovered,
    bool? hasSecurity,
    bool? hasCctv,
    bool? hasEvCharging,
    List<String>? allowedVehicleTypes,
    double? hourlyRate,
    double? dailyRate,
    double? weeklyRate,
    double? monthlyRate,
    double? yearlyRate,
    Map<String, int>? slotCapacity,
    Map<String, int>? slotAvailable,
    Map<String, dynamic>? availabilitySchedule,
    String? bookingMode,
    bool? isActive,
    bool? isSuspended,
    List<String>? photos,
    String? videoUrl,
    String? contactPhone,
  }) {
    return ListingModel(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isCovered: isCovered ?? this.isCovered,
      hasSecurity: hasSecurity ?? this.hasSecurity,
      hasCctv: hasCctv ?? this.hasCctv,
      hasEvCharging: hasEvCharging ?? this.hasEvCharging,
      allowedVehicleTypes: allowedVehicleTypes ?? this.allowedVehicleTypes,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      dailyRate: dailyRate ?? this.dailyRate,
      weeklyRate: weeklyRate ?? this.weeklyRate,
      monthlyRate: monthlyRate ?? this.monthlyRate,
      yearlyRate: yearlyRate ?? this.yearlyRate,
      slotCapacity: slotCapacity ?? this.slotCapacity,
      slotAvailable: slotAvailable ?? this.slotAvailable,
      availabilitySchedule: availabilitySchedule ?? this.availabilitySchedule,
      bookingMode: bookingMode ?? this.bookingMode,
      isActive: isActive ?? this.isActive,
      isSuspended: isSuspended ?? this.isSuspended,
      photos: photos ?? this.photos,
      videoUrl: videoUrl ?? this.videoUrl,
      // QR identity is server-owned; carry it through untouched.
      qrToken: qrToken,
      qrShortCode: qrShortCode,
      contactPhone: contactPhone ?? this.contactPhone,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
