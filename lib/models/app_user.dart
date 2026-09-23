import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/core/constants.dart';

enum UserRole { customer, technician, admin }

enum VerificationStatus { pending, approved, rejected }

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    this.address = '',
    this.idCard = '',
    this.ratingAvg = 5,
    this.ratingCount = 0,
    this.fcmToken,
    this.isOnline = false,
    this.geo,
    this.serviceIds = const [],
    this.vehicleTypeIds = const [],
    this.verified = false,
    this.verificationStatus = VerificationStatus.pending,
    this.walletBalance = 0,
  });

  final String id;
  final UserRole role;
  final String name;
  final String phone;
  final String address;
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
  final bool verified;
  final VerificationStatus verificationStatus;
  final double walletBalance;

  bool get isTechnician => role == UserRole.technician;
  bool get isAdmin => role == UserRole.admin;
  bool get isApproved =>
      verificationStatus == VerificationStatus.approved ||
      (verified && verificationStatus != VerificationStatus.rejected);

  bool get canReceiveJobs =>
      isTechnician && isApproved && walletBalance >= AppConstants.minWalletBalance;

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'name': name,
        'phone': phone,
        'address': address,
        'idCard': idCard,
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
        'fcmToken': fcmToken,
        'isOnline': isOnline,
        'geo': geo,
        'serviceIds': serviceIds,
        'vehicleTypeIds': vehicleTypeIds,
        'verified': verified,
        'verificationStatus': verificationStatus.name,
        'walletBalance': walletBalance,
      };

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final roleRaw = d['role'] as String?;
    final verifiedFlag = d['verified'] == true;
    return AppUser(
      id: doc.id,
      role: UserRole.values.firstWhere(
        (r) => r.name == roleRaw,
        orElse: () => UserRole.customer,
      ),
      name: d['name'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      address: d['address'] as String? ?? '',
      idCard: d['idCard'] as String? ?? '',
      ratingAvg: (d['ratingAvg'] as num?)?.toDouble() ?? 5,
      ratingCount: (d['ratingCount'] as num?)?.toInt() ?? 0,
      fcmToken: d['fcmToken'] as String?,
      isOnline: d['isOnline'] as bool? ?? false,
      geo: d['geo'] as GeoPoint?,
      serviceIds: List<String>.from(d['serviceIds'] as List? ?? const []),
      vehicleTypeIds:
          List<String>.from(d['vehicleTypeIds'] as List? ?? const []),
      verified: verifiedFlag,
      verificationStatus: _statusOf(d['verificationStatus'], verifiedFlag),
      walletBalance: (d['walletBalance'] as num?)?.toDouble() ?? 0,
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
    bool? isOnline,
    GeoPoint? geo,
    String? fcmToken,
    List<String>? serviceIds,
    List<String>? vehicleTypeIds,
    bool? verified,
    VerificationStatus? verificationStatus,
    double? walletBalance,
  }) {
    return AppUser(
      id: id,
      role: role,
      name: name,
      phone: phone,
      address: address,
      idCard: idCard,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      fcmToken: fcmToken ?? this.fcmToken,
      isOnline: isOnline ?? this.isOnline,
      geo: geo ?? this.geo,
      serviceIds: serviceIds ?? this.serviceIds,
      vehicleTypeIds: vehicleTypeIds ?? this.vehicleTypeIds,
      verified: verified ?? this.verified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }
}
