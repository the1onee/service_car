import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/legal/terms_of_use.dart';

enum UserRole { customer, technician, workshop, oilWorkshop, paintShop, admin }

enum VerificationStatus { pending, approved, rejected }

/// تصنيف ورشة الزيوت: وكالة أصلية أو موثوقة.
enum OilWorkshopTier { agency, trusted }

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    this.address = '',
    this.photoUrl = '',
    this.idCard = '',
    this.ratingAvg = 5,
    this.ratingCount = 0,
    this.fcmToken,
    this.isOnline = false,
    this.geo,
    this.serviceIds = const [],
    this.vehicleTypeIds = const [],
    this.specialtyId = '',
    this.specialtyAr = '',
    this.workshopOps = '',
    this.cityId = '',
    this.cityNameAr = '',
    this.oilWorkshopTier,
    this.verified = false,
    this.verificationStatus = VerificationStatus.pending,
    this.walletBalance = 0,
    this.commissionPercent = 0,
    this.termsAcceptedVersion = '',
  });

  final String id;
  final UserRole role;
  final String name;
  final String phone;
  final String address;
  /// رابط صورة الملف الشخصي (Cloudinary).
  final String photoUrl;
  /// رقم البطاقة الوطنية / هوية — اختياري.
  final String idCard;
  final double ratingAvg;
  final int ratingCount;
  final String? fcmToken;
  final bool isOnline;
  final GeoPoint? geo;
  final List<String> serviceIds;
  /// أنواع السيارات التي يستطيع الفني العمل عليها (صالون، باص…).
  final List<String> vehicleTypeIds;
  /// معرّف الاختصاص من كتالوج الأدمن.
  final String specialtyId;
  /// اختصاص الورشة (نص معروض).
  final String specialtyAr;
  /// عمليات مهمة تقدّمها الورشة.
  final String workshopOps;
  /// مدينة الورشة (basra, baghdad…).
  final String cityId;
  final String cityNameAr;
  /// وكالة أصلية أو موثوقة — لورش الزيوت فقط.
  final OilWorkshopTier? oilWorkshopTier;
  final bool verified;
  final VerificationStatus verificationStatus;
  final double walletBalance;
  /// نسبة عمولة ورشة القطع (٥ تعني ٥٪). يحدّدها الأدمن عند التسجيل.
  final double commissionPercent;

  /// آخر نسخة شروط استخدام وافق عليها المستخدم.
  final String termsAcceptedVersion;

  bool get hasAcceptedCurrentTerms =>
      termsAcceptedVersion.trim() == AppTerms.version;

  bool get isTechnician => role == UserRole.technician;
  bool get isWorkshop => role == UserRole.workshop;
  bool get isOilWorkshop => role == UserRole.oilWorkshop;
  bool get isPaintShop => role == UserRole.paintShop;
  bool get isAdmin => role == UserRole.admin;
  bool get isApproved =>
      verificationStatus == VerificationStatus.approved ||
      (verified && verificationStatus != VerificationStatus.rejected);

  bool get canReceiveJobs =>
      (isTechnician || isWorkshop || isOilWorkshop || isPaintShop) &&
      isApproved &&
      (isPaintShop || walletBalance >= AppConstants.minWalletBalance);

  /// الورشة/الفني مقفل عند نقص الرصيد عن الحد الأدنى (ورش الدهان مستثناة).
  bool isWalletLocked([double? minBalance]) {
    if (isPaintShop) return false;
    final min = minBalance ?? AppConstants.minWalletBalance;
    return walletBalance < min;
  }

  double requiredTopUp([double? minBalance]) {
    final min = minBalance ?? AppConstants.minWalletBalance;
    final need = min - walletBalance;
    return need > 0 ? need : 0;
  }

  String get oilWorkshopTierLabel {
    return switch (oilWorkshopTier) {
      OilWorkshopTier.agency => 'وكالة أصلية',
      OilWorkshopTier.trusted => 'موثوقة',
      null => 'ورشة زيوت',
    };
  }

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'name': name,
        'phone': phone,
        'address': address,
        'photoUrl': photoUrl,
        'idCard': idCard,
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
        'fcmToken': fcmToken,
        'isOnline': isOnline,
        'geo': geo,
        'serviceIds': serviceIds,
        'vehicleTypeIds': vehicleTypeIds,
        'specialtyId': specialtyId,
        'specialtyAr': specialtyAr,
        'workshopOps': workshopOps,
        'cityId': cityId,
        'cityNameAr': cityNameAr,
        if (oilWorkshopTier != null) 'oilWorkshopTier': oilWorkshopTier!.name,
        'verified': verified,
        'verificationStatus': verificationStatus.name,
        'walletBalance': walletBalance,
        'commissionPercent': commissionPercent,
        if (termsAcceptedVersion.isNotEmpty)
          'termsAcceptedVersion': termsAcceptedVersion,
      };

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AppUser._fromData(doc.id, doc.data() ?? {});
  }

  factory AppUser.fromCache(Map<String, dynamic> raw) {
    final d = Map<String, dynamic>.from(raw);
    final geoRaw = d['geo'];
    if (geoRaw is Map) {
      final lat = (geoRaw['lat'] as num?)?.toDouble();
      final lng = (geoRaw['lng'] as num?)?.toDouble();
      d['geo'] = (lat != null && lng != null) ? GeoPoint(lat, lng) : null;
    }
    return AppUser._fromData(d['id'] as String? ?? '', d);
  }

  factory AppUser._fromData(String id, Map<String, dynamic> d) {
    final roleRaw = d['role'] as String?;
    final verifiedFlag = d['verified'] == true;
    final tierRaw = d['oilWorkshopTier'] as String?;
    return AppUser(
      id: id,
      role: UserRole.values.firstWhere(
        (r) => r.name == roleRaw,
        orElse: () => UserRole.customer,
      ),
      name: d['name'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      address: d['address'] as String? ?? '',
      photoUrl: d['photoUrl'] as String? ?? '',
      idCard: d['idCard'] as String? ?? '',
      ratingAvg: (d['ratingAvg'] as num?)?.toDouble() ?? 5,
      ratingCount: (d['ratingCount'] as num?)?.toInt() ?? 0,
      fcmToken: d['fcmToken'] as String?,
      isOnline: d['isOnline'] == true,
      geo: d['geo'] as GeoPoint?,
      serviceIds: List<String>.from(d['serviceIds'] as List? ?? const []),
      vehicleTypeIds:
          List<String>.from(d['vehicleTypeIds'] as List? ?? const []),
      specialtyId: d['specialtyId'] as String? ?? '',
      specialtyAr: d['specialtyAr'] as String? ?? '',
      workshopOps: d['workshopOps'] as String? ?? '',
      cityId: d['cityId'] as String? ?? '',
      cityNameAr: d['cityNameAr'] as String? ?? '',
      oilWorkshopTier: () {
        if (tierRaw == null || tierRaw.isEmpty) return null;
        for (final t in OilWorkshopTier.values) {
          if (t.name == tierRaw) return t;
        }
        return null;
      }(),
      verified: verifiedFlag,
      verificationStatus: _statusOf(d['verificationStatus'], verifiedFlag),
      walletBalance: (d['walletBalance'] as num?)?.toDouble() ?? 0,
      commissionPercent: (d['commissionPercent'] as num?)?.toDouble() ?? 0,
      termsAcceptedVersion: d['termsAcceptedVersion'] as String? ?? '',
    );
  }

  static VerificationStatus _statusOf(Object? raw, bool verified) {
    final name = raw is String ? raw.trim().toLowerCase() : '';
    final status = VerificationStatus.values.firstWhere(
      (v) => v.name == name,
      orElse: () => VerificationStatus.pending,
    );
    if (status == VerificationStatus.pending && verified) {
      return VerificationStatus.approved;
    }
    return status;
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? address,
    String? photoUrl,
    bool? isOnline,
    GeoPoint? geo,
    String? fcmToken,
    List<String>? serviceIds,
    List<String>? vehicleTypeIds,
    String? specialtyId,
    String? specialtyAr,
    String? workshopOps,
    String? cityId,
    String? cityNameAr,
    OilWorkshopTier? oilWorkshopTier,
    bool? verified,
    VerificationStatus? verificationStatus,
    double? walletBalance,
    String? termsAcceptedVersion,
  }) {
    return AppUser(
      id: id,
      role: role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      photoUrl: photoUrl ?? this.photoUrl,
      idCard: idCard,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      fcmToken: fcmToken ?? this.fcmToken,
      isOnline: isOnline ?? this.isOnline,
      geo: geo ?? this.geo,
      serviceIds: serviceIds ?? this.serviceIds,
      vehicleTypeIds: vehicleTypeIds ?? this.vehicleTypeIds,
      specialtyId: specialtyId ?? this.specialtyId,
      specialtyAr: specialtyAr ?? this.specialtyAr,
      workshopOps: workshopOps ?? this.workshopOps,
      cityId: cityId ?? this.cityId,
      cityNameAr: cityNameAr ?? this.cityNameAr,
      oilWorkshopTier: oilWorkshopTier ?? this.oilWorkshopTier,
      verified: verified ?? this.verified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      walletBalance: walletBalance ?? this.walletBalance,
      commissionPercent: commissionPercent,
      termsAcceptedVersion: termsAcceptedVersion ?? this.termsAcceptedVersion,
    );
  }
}
