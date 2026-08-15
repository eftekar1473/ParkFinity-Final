import '../../../features/owner/data/models/listing_model.dart';

class BookingModel {
  final String? id;
  final String riderId;
  final String listingId;
  final String? vehicleId;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? actualEndTime;
  final double totalAmount;
  final double commissionAmount;
  final double ownerEarnings;
  final double baseAmount;
  final double overstayAmount;
  final String? durationType;
  final String? vehicleType;
  final int slotQty;
  final bool isRefunded;
  final String status; // 'Pending', 'Confirmed', 'Active', 'Completed', 'Cancelled', 'Overstayed', 'Refunded'
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final bool noShow;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ListingModel? listing; // joined relation

  BookingModel({
    this.id,
    required this.riderId,
    required this.listingId,
    this.vehicleId,
    required this.startTime,
    required this.endTime,
    this.actualEndTime,
    required this.totalAmount,
    this.commissionAmount = 0.0,
    this.ownerEarnings = 0.0,
    this.baseAmount = 0.0,
    this.overstayAmount = 0.0,
    this.durationType,
    this.vehicleType,
    this.slotQty = 1,
    this.isRefunded = false,
    this.status = 'Pending',
    this.checkedInAt,
    this.checkedOutAt,
    this.noShow = false,
    this.createdAt,
    this.updatedAt,
    this.listing,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String?,
      riderId: json['rider_id'] as String,
      listingId: json['listing_id'] as String,
      vehicleId: json['vehicle_id'] as String?,
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      actualEndTime: json['actual_end_time'] != null
          ? DateTime.parse(json['actual_end_time']).toLocal()
          : null,
      totalAmount: (json['total_amount'] as num).toDouble(),
      commissionAmount: (json['commission_amount'] as num).toDouble(),
      ownerEarnings: (json['owner_earnings'] as num).toDouble(),
      baseAmount: (json['base_amount'] as num?)?.toDouble() ?? 0,
      overstayAmount: (json['overstay_amount'] as num?)?.toDouble() ?? 0,
      durationType: json['duration_type'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      slotQty: (json['slot_qty'] as num?)?.toInt() ?? 1,
      isRefunded: json['is_refunded'] as bool? ?? false,
      status: json['status'] as String? ?? 'Pending',
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at']).toLocal()
          : null,
      checkedOutAt: json['checked_out_at'] != null
          ? DateTime.parse(json['checked_out_at']).toLocal()
          : null,
      noShow: json['no_show'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at']).toLocal()
          : null,
      listing: json['listings'] != null
          ? ListingModel.fromJson(json['listings'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'rider_id': riderId,
      'listing_id': listingId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      if (actualEndTime != null)
        'actual_end_time': actualEndTime!.toUtc().toIso8601String(),
      'total_amount': totalAmount,
      'commission_amount': commissionAmount,
      'owner_earnings': ownerEarnings,
      'status': status,
    };
  }
}
