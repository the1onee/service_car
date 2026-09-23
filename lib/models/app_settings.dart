import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/core/constants.dart';

class AppSettings {
  static const defaultTopUpCardNumber = '482561772';
  static const defaultTopUpCardLabel = 'بطاقة الرافدين — ماستركارد';
  static const defaultTopUpInstructions =
      'توجه إلى حسابك في تطبيق كي كارد (Qi Card) أو سوبر كي، ثم حوّل المبلغ إلى الرقم أدناه. '
      'بعد إتمام التحويل صوّر فاتورة التحويل وأضفها هنا ليتم إضافة المبلغ إلى محفظتك بعد موافقة الإدارة.';

  const AppSettings({
    this.activeCityId = 'basra',
    this.defaultZoom = 12,
    this.maxMatchKm = AppConstants.maxMatchKm,
    this.commissionPercent = 10,
    this.minWalletBalance = AppConstants.minWalletBalance,
    this.topUpCardNumber = defaultTopUpCardNumber,
    this.topUpCardLabel = defaultTopUpCardLabel,
    this.topUpAccountName = '',
    this.topUpInstructions = defaultTopUpInstructions,
  });

  final String activeCityId;
  final double defaultZoom;
  final double maxMatchKm;
  final double commissionPercent;
  final double minWalletBalance;
  final String topUpCardNumber;
  final String topUpCardLabel;
  final String topUpAccountName;
  final String topUpInstructions;

  factory AppSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const AppSettings();
    String str(String key, String fallback) {
      final v = data[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return fallback;
    }

    return AppSettings(
      activeCityId: (data['activeCityId'] as String?)?.trim().isNotEmpty == true
          ? (data['activeCityId'] as String).trim()
          : 'basra',
      defaultZoom: (data['defaultZoom'] as num?)?.toDouble() ?? 12,
      maxMatchKm: (data['maxMatchKm'] as num?)?.toDouble() ?? AppConstants.maxMatchKm,
      commissionPercent: (data['commissionPercent'] as num?)?.toDouble() ?? 10,
      minWalletBalance:
          (data['minWalletBalance'] as num?)?.toDouble() ?? AppConstants.minWalletBalance,
      topUpCardNumber: str('topUpCardNumber', defaultTopUpCardNumber),
      topUpCardLabel: str('topUpCardLabel', defaultTopUpCardLabel),
      topUpAccountName: str('topUpAccountName', ''),
      topUpInstructions: str('topUpInstructions', defaultTopUpInstructions),
    );
  }
}

class CityZone {
  const CityZone({
    required this.id,
    required this.nameAr,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    this.active = true,
  });

  final String id;
  final String nameAr;
  final double centerLat;
  final double centerLng;
  final double radiusKm;
  final bool active;

  factory CityZone.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CityZone(
      id: doc.id,
      nameAr: d['nameAr'] as String? ?? doc.id,
      centerLat: (d['centerLat'] as num?)?.toDouble() ?? AppConstants.defaultLat,
      centerLng: (d['centerLng'] as num?)?.toDouble() ?? AppConstants.defaultLng,
      radiusKm: (d['radiusKm'] as num?)?.toDouble() ?? 50,
      active: d['active'] as bool? ?? true,
    );
  }
}
