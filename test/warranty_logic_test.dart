import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/features/warranty/warranty_claim_logic.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/warranty.dart';
import 'package:barrr/models/warranty_claim.dart';

Job _job({
  required String id,
  required String serviceId,
  String providerKind = '',
  Warranty warranty = const Warranty(enabled: false),
  String? technicianId = 'prov1',
}) {
  return Job(
    id: id,
    customerId: 'cust',
    serviceId: serviceId,
    status: JobStatus.completed,
    matchingMode: MatchingMode.quotes,
    approxLocation: const GeoPoint(30.5, 47.8),
    createdAt: DateTime.now(),
    providerKind: providerKind,
    technicianId: technicianId,
    warranty: warranty,
  );
}

void main() {
  group('warranty lifecycle', () {
    test('disabled warranty is never active', () {
      const w = Warranty(enabled: false, days: 2);
      expect(warrantyIsActive(w), isFalse);
      expect(warrantyEndsAt(w), isNull);
      expect(warrantyLabel(w), 'بدون ضمان');
      expect(warrantyRemainingLabel(w), 'بدون ضمان');
    });

    test('enabled without startsAt waits for completion activation', () {
      const w = Warranty(
        enabled: true,
        type: WarrantyType.part,
        days: 2,
        note: 'ضمان قطعة',
      );
      expect(warrantyIsActive(w), isFalse);
      expect(warrantyEndsAt(w), isNull);
      expect(warrantyRemainingLabel(w), 'بانتظار تفعيل الضمان');
      expect(warrantyLabel(w), contains('القطعة'));
    });

    test('startsAt on complete makes parts warranty active for days', () {
      final start = DateTime.now().subtract(const Duration(hours: 1));
      final w = Warranty(
        enabled: true,
        type: WarrantyType.part,
        days: AppConstants.warrantyDays,
        startsAt: start,
      );
      expect(warrantyIsActive(w), isTrue);
      final end = warrantyEndsAt(w)!;
      expect(end.difference(start).inDays, AppConstants.warrantyDays);
      expect(warrantyRemainingLabel(w), isNot(contains('انتهى')));
    });

    test('expired warranty is inactive', () {
      final start = DateTime.now().subtract(const Duration(days: 10));
      final w = Warranty(
        enabled: true,
        type: WarrantyType.work,
        days: 2,
        startsAt: start,
      );
      expect(warrantyIsActive(w), isFalse);
      expect(warrantyRemainingLabel(w), 'انتهى الضمان');
    });
  });

  group('parts / wash product rules', () {
    test('parts job with enabled warranty becomes active after startsAt', () {
      final start = DateTime.now().subtract(const Duration(minutes: 5));
      final job = _job(
        id: 'parts1',
        serviceId: 'parts',
        providerKind: 'workshop',
        warranty: Warranty(
          enabled: true,
          type: WarrantyType.part,
          days: 2,
          note: 'ضمان 2 يوم',
          startsAt: start,
        ),
      );
      expect(job.isPartsOrder, isTrue);
      expect(job.warranty.enabled, isTrue);
      expect(warrantyIsActive(job.warranty), isTrue);
      expect(canOpenWarrantyClaim(job), isTrue);
      expect(claimProviderKindForJob(job), 'workshop');
    });

    test('wash tow oil do not support warranty claims', () {
      final start = DateTime.now().subtract(const Duration(minutes: 5));
      final active = Warranty(
        enabled: true,
        type: WarrantyType.work,
        days: 2,
        startsAt: start,
      );
      final wash = _job(id: 'wash1', serviceId: 'wash', warranty: active);
      final tow = _job(id: 'tow1', serviceId: 'towing', warranty: active);
      final oil = _job(
        id: 'oil1',
        serviceId: 'oil',
        providerKind: 'oilWorkshop',
        warranty: active,
      );
      expect(jobSupportsWarrantyClaims(wash), isFalse);
      expect(jobSupportsWarrantyClaims(tow), isFalse);
      expect(jobSupportsWarrantyClaims(oil), isFalse);
      expect(canOpenWarrantyClaim(wash), isFalse);
      expect(canOpenWarrantyClaim(tow), isFalse);
      expect(canOpenWarrantyClaim(oil), isFalse);
    });

    test('technician field job supports warranty claims when active', () {
      final start = DateTime.now().subtract(const Duration(minutes: 5));
      final job = _job(
        id: 'tech1',
        serviceId: 'battery',
        providerKind: 'field_tech',
        warranty: Warranty(
          enabled: true,
          type: WarrantyType.work,
          days: 2,
          startsAt: start,
        ),
      );
      expect(jobSupportsWarrantyClaims(job), isTrue);
      expect(canOpenWarrantyClaim(job), isTrue);
      expect(claimProviderKindForJob(job), 'technician');
    });
  });

  group('warranty claim status cycle', () {
    test('open claim past respondBy is overdue effectively', () {
      final claim = WarrantyClaim(
        id: 'c1',
        jobId: 'j1',
        customerId: 'cust',
        providerId: 'prov',
        providerKind: 'workshop',
        claimType: 'part_not_working',
        status: WarrantyClaimStatus.open,
        respondBy: DateTime.now().subtract(const Duration(hours: 1)),
        createdAt: DateTime.now().subtract(const Duration(hours: 25)),
      );
      expect(claim.effectiveStatus, WarrantyClaimStatus.overdue);
      expect(claim.isOpen, isTrue);
      expect(claimStatusIsActive(claim.status), isTrue);
      expect(slaRemainingLabel(claim), contains('تجاوزت'));
    });

    test('resolved claim stays resolved', () {
      final claim = WarrantyClaim(
        id: 'c2',
        jobId: 'j1',
        customerId: 'cust',
        providerId: 'prov',
        providerKind: 'technician',
        claimType: 'same_fault',
        status: WarrantyClaimStatus.resolved,
        resolution: WarrantyClaimResolution.fixedOnsite,
        respondBy: DateTime.now().subtract(const Duration(hours: 30)),
      );
      expect(claim.effectiveStatus, WarrantyClaimStatus.resolved);
      expect(claim.isOpen, isFalse);
      expect(
        WarrantyClaim.resolutionLabel(claim.resolution),
        'تم الحل في الموقع',
      );
    });

    test('claim type labels cover workshop replacement', () {
      expect(
        WarrantyClaim.claimTypeLabel('part_not_working'),
        contains('استبدال'),
      );
    });

    test('status firestore round-trip', () {
      expect(
        WarrantyClaim.statusFromFirestore('in_progress'),
        WarrantyClaimStatus.inProgress,
      );
      expect(
        WarrantyClaim.statusToFirestore(WarrantyClaimStatus.acknowledged),
        'acknowledged',
      );
      expect(
        WarrantyClaim.resolutionFromFirestore('part_shipped'),
        WarrantyClaimResolution.partShipped,
      );
    });
  });
}
