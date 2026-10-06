import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/models/job.dart';

Job _job({
  required String id,
  required JobStatus status,
  String serviceId = 'wash',
  MatchingMode matchingMode = MatchingMode.quotes,
  String providerKind = '',
  double? initialPrice,
  double? finalPrice,
  bool useWallet = false,
  double walletReserve = 0,
}) {
  return Job(
    id: id,
    customerId: 'c1',
    serviceId: serviceId,
    serviceTitle: 'خدمة',
    status: status,
    matchingMode: matchingMode,
    commissionRate: AppConstants.commissionRate,
    approxLocation: const GeoPoint(30.5, 47.7),
    createdAt: DateTime(2026, 1, 1),
    providerKind: providerKind,
    initialPrice: initialPrice,
    finalPrice: finalPrice,
    useWallet: useWallet,
    walletReserve: walletReserve,
  );
}

void main() {
  group('jobStatusFrom / matchingModeFrom', () {
    test('parses known status names', () {
      expect(jobStatusFrom('enRoute'), JobStatus.enRoute);
      expect(jobStatusFrom('completed'), JobStatus.completed);
      expect(jobStatusFrom('unknown'), JobStatus.dispatching);
    });

    test('matchingModeFrom uses raw then emergency service fallback', () {
      expect(matchingModeFrom('emergency'), MatchingMode.emergency);
      expect(matchingModeFrom('quotes'), MatchingMode.quotes);
      expect(matchingModeFrom(null, 'towing'), MatchingMode.emergency);
      expect(matchingModeFrom(null, 'wash'), MatchingMode.quotes);
    });
  });

  group('job kind getters', () {
    test('parts oil wash tow paint technician classification', () {
      expect(_job(id: '1', status: JobStatus.quoted, serviceId: 'parts').isPartsOrder,
          isTrue);
      expect(
          _job(
            id: '2',
            status: JobStatus.quoted,
            serviceId: 'x',
            providerKind: 'workshop',
          ).isPartsOrder,
          isTrue);
      expect(_job(id: '3', status: JobStatus.quoted, serviceId: 'oil').isOilOrder,
          isTrue);
      expect(_job(id: '4', status: JobStatus.quoted, serviceId: 'wash').isWashOrder,
          isTrue);
      expect(_job(id: '5', status: JobStatus.quoted, serviceId: 'towing').isTowOrder,
          isTrue);
      expect(
        _job(
          id: '6',
          status: JobStatus.quoted,
          serviceId: 'paint',
          matchingMode: MatchingMode.quotes,
        ).isPaintOrder,
        isTrue,
      );
      expect(
        _job(id: '7', status: JobStatus.quoted, serviceId: 'battery').isTechnicianJob,
        isTrue,
      );
    });

    test('open-ended dispatch for non-emergency parts/oil/tech', () {
      expect(
        _job(id: 'a', status: JobStatus.dispatching, serviceId: 'parts')
            .isOpenEndedDispatch,
        isTrue,
      );
      expect(
        _job(
          id: 'b',
          status: JobStatus.dispatching,
          serviceId: 'towing',
          matchingMode: MatchingMode.emergency,
        ).isOpenEndedDispatch,
        isFalse,
      );
    });
  });

  group('lifecycle permissions', () {
    test('customerCanCancel on open statuses only', () {
      expect(
        _job(id: '1', status: JobStatus.dispatching).customerCanCancel,
        isTrue,
      );
      expect(
        _job(id: '2', status: JobStatus.enRoute).customerCanCancel,
        isTrue,
      );
      expect(
        _job(id: '3', status: JobStatus.inProgress).customerCanCancel,
        isFalse,
      );
      expect(
        _job(id: '4', status: JobStatus.completed).customerCanCancel,
        isFalse,
      );
    });

    test('technicianCanWithdraw limited statuses', () {
      expect(
        _job(id: '1', status: JobStatus.quoted).technicianCanWithdraw,
        isTrue,
      );
      expect(
        _job(id: '2', status: JobStatus.arrived).technicianCanWithdraw,
        isTrue,
      );
      expect(
        _job(id: '3', status: JobStatus.dispatching).technicianCanWithdraw,
        isFalse,
      );
      expect(
        _job(id: '4', status: JobStatus.completed).technicianCanWithdraw,
        isFalse,
      );
    });

    test('locationRevealed after assignment', () {
      expect(
        _job(id: '1', status: JobStatus.offerPending).locationRevealed,
        isFalse,
      );
      expect(
        _job(id: '2', status: JobStatus.enRoute).locationRevealed,
        isTrue,
      );
      expect(
        _job(id: '3', status: JobStatus.completed).locationRevealed,
        isTrue,
      );
    });
  });

  group('billing helpers', () {
    test('billAmount prefers final then initial', () {
      expect(
        _job(
          id: '1',
          status: JobStatus.completed,
          initialPrice: 5000,
          finalPrice: 8000,
        ).billAmount,
        8000,
      );
      expect(
        _job(id: '2', status: JobStatus.quoted, initialPrice: 5000).billAmount,
        5000,
      );
      expect(
        _job(id: '3', status: JobStatus.quoted).billAmount,
        0,
      );
    });

    test('cashDue subtracts wallet reserve', () {
      expect(
        _job(
          id: '1',
          status: JobStatus.finalQuote,
          finalPrice: 10000,
          useWallet: true,
          walletReserve: 3000,
        ).cashDue,
        7000,
      );
      expect(
        _job(
          id: '2',
          status: JobStatus.finalQuote,
          finalPrice: 10000,
          useWallet: false,
          walletReserve: 3000,
        ).cashDue,
        10000,
      );
      expect(
        _job(
          id: '3',
          status: JobStatus.finalQuote,
          finalPrice: 2000,
          useWallet: true,
          walletReserve: 5000,
        ).cashDue,
        0,
      );
    });
  });

  group('status buckets across pipeline', () {
    test('pipeline statuses classify open/done/closed', () {
      const openStatuses = [
        JobStatus.dispatching,
        JobStatus.offerPending,
        JobStatus.comparing,
        JobStatus.quoted,
        JobStatus.enRoute,
        JobStatus.arrived,
        JobStatus.finalQuote,
        JobStatus.inProgress,
      ];
      for (final s in openStatuses) {
        expect(jobIsOpen(_job(id: s.name, status: s)), isTrue, reason: s.name);
      }
      expect(jobIsDone(_job(id: 'c', status: JobStatus.completed)), isTrue);
      expect(jobIsDone(_job(id: 'r', status: JobStatus.rated)), isTrue);
      expect(jobIsClosed(_job(id: 'x', status: JobStatus.cancelled)), isTrue);
      expect(jobIsClosed(_job(id: 'n', status: JobStatus.noTechnician)), isTrue);
    });
  });

  group('matching constants', () {
    test('dispatch rounds and windows', () {
      expect(AppConstants.emergencyOfferSeconds, 30);
      expect(AppConstants.quoteWindowSeconds, 150);
      expect(AppConstants.maxQuotes, 3);
      expect(AppConstants.maxDispatchRounds, 3);
      expect(AppConstants.emergencyTechsPerRound, 2);
      expect(AppConstants.quoteTechsPerRound, 8);
    });
  });
}
