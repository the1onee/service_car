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
    this.specialtyAr = '',
    this.partImageUrl = '',
    this.partNote = '',
    this.carYear = '',
    this.oilTypeId = '',
    this.oilTypeName = '',
    this.cylinders = 0,
    this.liters = 0,
    this.includeOilFilter = false,
    this.landmark = '',
    this.washPackageId = '',
    this.washPackageName = '',
    this.createdAt,
  });

  final String id;
  final String jobId;
  final String technicianId;
  final OfferStatus status;
  final DateTime expiresAt;
  /// وقت إنشاء العرض — لإخفاء الطلبات الأقدم من يوم في لوحة الورشة.
  final DateTime? createdAt;
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
  final String specialtyAr;
  final String partImageUrl;
  final String partNote;
  final String carYear;
  final String oilTypeId;
  final String oilTypeName;
  final int cylinders;
  final double liters;
  final bool includeOilFilter;
  final String landmark;
  final String washPackageId;
  final String washPackageName;

  bool get isAgencyOilWorkshop => oilWorkshopTier == 'agency';
  bool get isTrustedOilWorkshop => oilWorkshopTier == 'trusted';

  /// عروض بلا مهلة قصيرة (قطع / زيوت) — لا تُغلق بعد دقائق.
  bool get isOpenEnded =>
      expiresAt.difference(DateTime.now()).inHours >= 12;

  bool get hasOilDetails =>
      oilTypeName.isNotEmpty ||
      oilTypeId.isNotEmpty ||
      cylinders > 0 ||
      liters > 0;

  bool get hasWashDetails =>
      washPackageName.isNotEmpty ||
      washPackageId.isNotEmpty;

  String get washDisplayTitle {
    if (washPackageName.trim().isNotEmpty) return washPackageName.trim();
    if (partName.trim().isNotEmpty) return partName.trim();
    return serviceTitle ?? 'غسيل سيارات';
  }

  String get oilDisplayTitle {
    if (oilTypeName.trim().isNotEmpty) return oilTypeName.trim();
    if (partName.trim().isNotEmpty) return partName.trim();
    return serviceTitle ?? 'تبديل زيت';
  }

  String get carSummary {
    final parts = <String>[
      if (carMake.trim().isNotEmpty) carMake.trim(),
      if (carModel.trim().isNotEmpty) carModel.trim(),
      if (carYear.trim().isNotEmpty) carYear.trim(),
    ];
    return parts.join(' ');
  }

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
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 365)),
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
      specialtyAr: d['specialtyAr'] as String? ?? '',
      partImageUrl: d['partImageUrl'] as String? ?? '',
      partNote: d['partNote'] as String? ?? '',
      carYear: d['carYear'] as String? ?? '',
      oilTypeId: d['oilTypeId'] as String? ?? '',
      oilTypeName: d['oilTypeName'] as String? ?? '',
      cylinders: (d['cylinders'] as num?)?.toInt() ?? 0,
      liters: (d['liters'] as num?)?.toDouble() ?? 0,
      includeOilFilter: d['includeOilFilter'] == true,
      landmark: d['landmark'] as String? ?? '',
      washPackageId: d['washPackageId'] as String? ?? '',
      washPackageName: d['washPackageName'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
