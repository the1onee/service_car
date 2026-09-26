import 'package:cloud_firestore/cloud_firestore.dart';

enum OfferStatus { pending, submitted, accepted, expired, rejected }

class JobOffer {
  const JobOffer({
    required this.id,
    required this.jobId,
    required this.technicianId,
    required this.status,
    required this.expiresAt,
    this.serviceTitle,
    this.vehicleTypeTitle,
    this.approxLocation,
    this.initialPrice,
    this.technicianName,
    this.ratingAvg = 5,
    this.distanceKm,
    this.verified = false,
    this.partName = '',
    this.carMake = '',
    this.carModel = '',
    this.partCondition = '',
    this.warrantyDays = 0,
    this.warrantyNote = '',
    this.deliveryType = '',
    this.vendorNote = '',
    this.oilWorkshopTier = '',
  });

  final String id;
  final String jobId;
  final String technicianId;
  final OfferStatus status;
  final DateTime expiresAt;
  final String? serviceTitle;
  final String? vehicleTypeTitle;
  final GeoPoint? approxLocation;
  final double? initialPrice;
  final String? technicianName;
  final double ratingAvg;
  final double? distanceKm;
  final bool verified;
  final String partName;
  final String carMake;
  final String carModel;
  final String partCondition;
  final int warrantyDays;
  final String warrantyNote;
  final String deliveryType;
  final String vendorNote;
  /// agency | trusted — لورش الزيوت.
  final String oilWorkshopTier;

  bool get isAgencyOilWorkshop => oilWorkshopTier == 'agency';
  bool get isTrustedOilWorkshop => oilWorkshopTier == 'trusted';

  int remainingSeconds() {
    final s = expiresAt.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  factory JobOffer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final raw = d['status'] as String? ?? 'pending';
    return JobOffer(
      id: doc.id,
      jobId: d['jobId'] as String? ?? '',
      technicianId: d['technicianId'] as String? ?? '',
      status: OfferStatus.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => OfferStatus.pending,
      ),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      serviceTitle: d['serviceTitle'] as String?,
      vehicleTypeTitle: d['vehicleTypeTitle'] as String?,
      approxLocation: d['approxLocation'] as GeoPoint?,
      initialPrice: (d['initialPrice'] as num?)?.toDouble(),
      technicianName: d['technicianName'] as String?,
      ratingAvg: (d['ratingAvg'] as num?)?.toDouble() ?? 5,
      distanceKm: (d['distanceKm'] as num?)?.toDouble(),
      verified: d['verified'] == true,
      partName: d['partName'] as String? ?? '',
      carMake: d['carMake'] as String? ?? '',
      carModel: d['carModel'] as String? ?? '',
      partCondition: d['partCondition'] as String? ?? '',
      warrantyDays: (d['warrantyDays'] as num?)?.toInt() ?? 0,
      warrantyNote: d['warrantyNote'] as String? ?? '',
      deliveryType: d['deliveryType'] as String? ?? '',
      vendorNote: d['vendorNote'] as String? ?? '',
      oilWorkshopTier: d['oilWorkshopTier'] as String? ?? '',
    );
  }
}
