import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/oil_type.dart';
import 'package:barrr/models/vehicle_type.dart';

void main() {
  testWidgets('theme builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Text(AppStrings.appName)),
      ),
    );
    expect(find.text(AppStrings.appName), findsOneWidget);
  });

  group('service catalog', () {
    test('seed services include core customer entry points', () {
      expect(seedServices.length, 13);
      final ids = seedServices.map((s) => s.id).toSet();
      expect(
        ids.containsAll({
          'technician',
          'oil',
          'wash',
          'parts',
          'towing',
          'locks',
          'fuel',
        }),
        isTrue,
      );
    });

    test('emergency vs quote services', () {
      expect(isEmergencyService('towing'), isFalse);
      expect(isEmergencyService('locks'), isTrue);
      expect(isEmergencyService('fuel'), isTrue);
      expect(isEmergencyService('oil'), isFalse);
      expect(isEmergencyService('wash'), isFalse);
      expect(isEmergencyService('technician'), isFalse);
    });

    test('technician entry filters exclude oil wash parts paint', () {
      final filtered = filterServicesForEntry('technician', seedServices);
      final ids = filtered.map((s) => s.id).toSet();
      expect(ids.contains('oil'), isFalse);
      expect(ids.contains('wash'), isFalse);
      expect(ids.contains('parts'), isFalse);
      expect(ids.contains('paint'), isFalse);
      expect(ids.contains('battery') || ids.contains('brakes'), isTrue);
    });

    test('dedicated entry ids resolve to themselves', () {
      expect(filterServicesForEntry('oil', seedServices).single.id, 'oil');
      expect(filterServicesForEntry('wash', seedServices).single.id, 'wash');
      expect(
          filterServicesForEntry('towing', seedServices).single.id, 'towing');
    });
  });

  group('app constants', () {
    test('geo and matching defaults', () {
      expect(AppConstants.defaultLat, closeTo(30.5085, 0.001));
      expect(AppConstants.defaultLng, closeTo(47.7830, 0.001));
      expect(AppConstants.emergencyTechsPerRound, 2);
      expect(AppConstants.commissionRate, 0.10);
    });
  });

  group('AppUser profile fields', () {
    test('parses photoUrl and keeps it in toMap/copyWith', () {
      final user = AppUser.fromCache({
        'id': 'u1',
        'role': 'customer',
        'name': 'محمد',
        'phone': '7700000000',
        'address': 'البصرة',
        'photoUrl': 'https://example.com/p.jpg',
        'walletBalance': 0,
      });
      expect(user.photoUrl, 'https://example.com/p.jpg');
      expect(user.toMap()['photoUrl'], 'https://example.com/p.jpg');

      final renamed = user.copyWith(name: 'علي', photoUrl: 'https://cdn/x.png');
      expect(renamed.name, 'علي');
      expect(renamed.photoUrl, 'https://cdn/x.png');
      expect(renamed.phone, '7700000000');
    });

    test('defaults empty photoUrl when missing', () {
      final user = AppUser.fromCache({
        'id': 'u2',
        'role': 'customer',
        'name': 'سارة',
        'phone': '771',
      });
      expect(user.photoUrl, '');
    });
  });

  group('OilType', () {
    test('fromMap sorts fields and defaults', () {
      final oil = OilType.fromMap('shell_5w40', {
        'nameAr': 'شيل هيلكس',
        'nameEn': 'Shell',
        'noteAr': 'مناسب للحرارة',
        'active': true,
        'sortOrder': 30,
      });
      expect(oil.id, 'shell_5w40');
      expect(oil.nameAr, 'شيل هيلكس');
      expect(oil.noteAr, 'مناسب للحرارة');
      expect(oil.sortOrder, 30);
      expect(oil.active, isTrue);
    });
  });

  group('vehicle seeds', () {
    test('seed vehicle types stay active and ordered', () {
      expect(seedVehicleTypes, isNotEmpty);
      expect(seedVehicleTypes.every((v) => v.active), isTrue);
      expect(seedVehicleTypes.first.id, 'sedan');
    });
  });

  group('job helpers', () {
    Job makeJob({
      required String id,
      required JobStatus status,
      String serviceId = 'wash',
    }) {
      return Job(
        id: id,
        customerId: 'c1',
        serviceId: serviceId,
        serviceTitle: 'خدمة',
        status: status,
        matchingMode: MatchingMode.quotes,
        commissionRate: 0.1,
        approxLocation: const GeoPoint(30.5, 47.7),
        createdAt: DateTime(2026, 1, 1),
      );
    }

    test('open done closed classification', () {
      expect(jobIsOpen(makeJob(id: 'a', status: JobStatus.dispatching)), isTrue);
      expect(jobIsDone(makeJob(id: 'b', status: JobStatus.completed)), isTrue);
      expect(jobIsDone(makeJob(id: 'c', status: JobStatus.rated)), isTrue);
      expect(jobIsClosed(makeJob(id: 'd', status: JobStatus.cancelled)), isTrue);
      expect(
          jobIsClosed(makeJob(id: 'e', status: JobStatus.noTechnician)), isTrue);
      expect(jobIsOpen(makeJob(id: 'f', status: JobStatus.completed)), isFalse);
    });

    test('jobCode shortens id', () {
      final code =
          jobCode(makeJob(id: 'abcdef123456', status: JobStatus.quoted));
      expect(code, '#ABCDEF');
    });
  });
}
