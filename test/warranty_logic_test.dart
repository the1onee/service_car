import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/warranty.dart';

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
      final job = Job(
        id: 'parts1',
        customerId: 'cust',
        serviceId: 'parts',
        serviceTitle: 'قطع غيار',
        status: JobStatus.completed,
        matchingMode: MatchingMode.quotes,
        approxLocation: const GeoPoint(30.5, 47.8),
        createdAt: DateTime.now(),
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
    });

    test('wash and tow keep warranty disabled at completion', () {
      final wash = Job(
        id: 'wash1',
        customerId: 'cust',
        serviceId: 'wash',
        status: JobStatus.completed,
        matchingMode: MatchingMode.quotes,
        approxLocation: const GeoPoint(30.5, 47.8),
        createdAt: DateTime.now(),
        warranty: const Warranty(enabled: false),
      );
      final tow = Job(
        id: 'tow1',
        customerId: 'cust',
        serviceId: 'towing',
        status: JobStatus.completed,
        matchingMode: MatchingMode.quotes,
        approxLocation: const GeoPoint(30.5, 47.8),
        createdAt: DateTime.now(),
        warranty: const Warranty(enabled: false),
      );
      expect(wash.isWashOrder, isTrue);
      expect(tow.isTowOrder, isTrue);
      // Matches tech_job_panel: wash/tow force warrantyEnabled false.
      final washEnabled =
          (wash.isWashOrder || wash.isTowOrder) ? false : wash.warranty.enabled;
      final towEnabled =
          (tow.isWashOrder || tow.isTowOrder) ? false : tow.warranty.enabled;
      expect(washEnabled, isFalse);
      expect(towEnabled, isFalse);
      expect(warrantyIsActive(wash.warranty), isFalse);
      expect(warrantyIsActive(tow.warranty), isFalse);
    });
  });
}
