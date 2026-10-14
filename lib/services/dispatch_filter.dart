import 'package:barrr/core/constants.dart';

/// بيانات مزوّد واحد مُستخرجة من Firestore لأغراض الفلترة والترتيب.
/// Record مسمّى بدلاً من anonymous record حتى يُمكن اختباره بسهولة.
class DispatchCandidate {
  const DispatchCandidate({
    required this.id,
    required this.online,
    required this.km,
    required this.token,
    required this.name,
    required this.rating,
    required this.verified,
    required this.wallet,
    required this.serviceIds,
    required this.vehicleTypeIds,
    required this.isWorkshop,
    required this.oilWorkshopTier,
    required this.specialtyId,
    required this.specialtyIds,
    required this.specialtyAr,
  });

  final String id;
  final bool online;
  final double km;
  final String? token;
  final String name;
  final double rating;
  final bool verified;
  final double wallet;
  final List<String> serviceIds;
  final List<String> vehicleTypeIds;
  final bool isWorkshop;
  final String oilWorkshopTier;
  final String specialtyId;
  final List<String> specialtyIds;
  final String specialtyAr;
}

/// معايير الفلترة التي تأتي من الطلب (Job) والإعدادات.
class DispatchFilter {
  const DispatchFilter({
    required this.isPartsOrder,
    required this.isOilOrder,
    required this.isPaintOrder,
    required this.isEmergency,
    required this.serviceId,
    required this.vehicleTypeId,
    required this.specialtyId,
    required this.minWallet,
    required this.usedProviderIds,
  });

  final bool isPartsOrder;
  final bool isOilOrder;
  final bool isPaintOrder;
  final bool isEmergency;
  final String serviceId;
  final String? vehicleTypeId;
  final String specialtyId;
  final double minWallet;
  final Set<String> usedProviderIds;
}

/// تصفية وترتيب المرشحين بدالة نقية (pure) قابلة للاختبار.
/// تُرجع قائمة مرتبة بالمسافة (الأقرب أولاً) ومحدودة بعدد أقصى.
List<DispatchCandidate> filterAndRankCandidates({
  required List<DispatchCandidate> all,
  required DispatchFilter filter,
  int? maxResults,
}) {
  final maxMatchKm = filter.isPartsOrder
      ? AppConstants.maxPartsMatchKm
      : AppConstants.maxMatchKm;

  final filtered = all.where((t) {
    // 1. يجب أن يكون معتمداً
    if (!t.verified) return false;

    // 2. فلترة الرصيد — ورش القطع معفيّة
    if (!filter.isPartsOrder) {
      if (!t.isWorkshop && t.wallet < filter.minWallet) return false;
    }

    // 3. استبعاد المزودين الذين استُخدموا سابقاً
    if (filter.usedProviderIds.contains(t.id)) return false;

    // 4. فلترة الخدمة
    if (!(t.isWorkshop && filter.isPartsOrder)) {
      if (t.serviceIds.isNotEmpty &&
          !t.serviceIds.contains(filter.serviceId)) {
        return false;
      }
    }

    // 5. فلترة المسافة
    if (t.km > maxMatchKm) return false;

    // 6. فلترة نوع المركبة
    if (!t.isWorkshop) {
      final needed = filter.vehicleTypeId;
      if (needed != null && needed.isNotEmpty && t.vehicleTypeIds.isNotEmpty) {
        if (!t.vehicleTypeIds.contains(needed)) return false;
      }
    }

    return true;
  }).toList();

  // 7. تطابق اختصاص صارم لطلبات القطع
  final specialized = filtered.where((t) {
    if (filter.isPartsOrder && filter.specialtyId.isNotEmpty) {
      return t.specialtyIds.contains(filter.specialtyId);
    }
    return true;
  }).toList();

  // 8. ترتيب بالمسافة
  specialized.sort((a, b) => a.km.compareTo(b.km));

  // 9. تطبيق الحد الأقصى
  final limit = maxResults ?? AppConstants.maxCandidatesPerDispatch;
  if (specialized.length > limit) {
    return specialized.sublist(0, limit);
  }
  return specialized;
}
