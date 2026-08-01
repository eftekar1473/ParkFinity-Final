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
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Nested relation
  final ListingModel? listing;

  BookingModel({
    this.id,
    required this.riderId,
    required this.listingId,
    this.vehicleId,
    required this.startTime,
    required this.endTime,
    this.actualEndTime,
    required this.totalAmount,
    required this.commissionAmount,
    required this.ownerEarnings,
    this.status = 'Pending',
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
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      actualEndTime: json['actual_end_time'] != null ? DateTime.parse(json['actual_end_time']) : null,
      totalAmount: (json['total_amount'] as num).toDouble(),
      commissionAmount: (json['commission_amount'] as num).toDouble(),
      ownerEarnings: (json['owner_earnings'] as num).toDouble(),
      status: json['status'] as String? ?? 'Pending',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      listing: json['listings'] != null ? ListingModel.fromJson(json['listings']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'rider_id': riderId,
      'listing_id': listingId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      if (actualEndTime != null) 'actual_end_time': actualEndTime!.toIso8601String(),
      'total_amount': totalAmount,
      'commission_amount': commissionAmount,
      'owner_earnings': ownerEarnings,
      'status': status,
    };
  }
}
