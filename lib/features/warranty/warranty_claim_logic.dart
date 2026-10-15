import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/warranty_claim.dart';

/// الضمان للمطالبة: ورشة قطع أو فني فقط — ليس غسيل/سطحة/زيت/دهان.
bool jobSupportsWarrantyClaims(Job job) {
  if (job.isWashOrder || job.isTowOrder || job.isOilOrder) return false;
  final kind = job.providerKind.trim();
  if (kind == 'paintShop' || kind == 'paint_shop') return false;
  if (job.isPartsOrder) return true;
  // طلبات الفني الميداني (أو أي خدمة غير المستثناة أعلاه).
  return kind.isEmpty ||
      kind == 'technician' ||
      kind == 'field_tech' ||
      kind == 'mobile';
}

bool canOpenWarrantyClaim(Job job) {
  return jobSupportsWarrantyClaims(job) && warrantyIsActive(job.warranty);
}

/// مسار المطالبة حسب نوع الطلب الأصلي.
String claimProviderKindForJob(Job job) {
  if (job.isPartsOrder) return 'workshop';
  return 'technician';
}

bool claimStatusIsActive(WarrantyClaimStatus status) {
  return status == WarrantyClaimStatus.open ||
      status == WarrantyClaimStatus.acknowledged ||
      status == WarrantyClaimStatus.inProgress ||
      status == WarrantyClaimStatus.overdue;
}

String slaRemainingLabel(WarrantyClaim claim) {
  if (claim.status != WarrantyClaimStatus.open &&
      claim.effectiveStatus != WarrantyClaimStatus.overdue) {
    return WarrantyClaim.statusLabel(claim.effectiveStatus);
  }
  final by = claim.respondBy;
  if (by == null) return 'مهلة الرد: 24 ساعة';
  final left = by.difference(DateTime.now());
  if (left.isNegative) return 'تجاوزت مهلة الـ 24 ساعة';
  if (left.inHours < 1) {
    final m = left.inMinutes.clamp(1, 59);
    return 'متبقي $m دقيقة للرد';
  }
  return 'متبقي ${left.inHours} ساعة للرد';
}
