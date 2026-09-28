import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/jobs/orders_screen.dart';
import 'package:barrr/models/job.dart';

void main() {
  Job job({
    required String id,
    required JobStatus status,
  }) {
    return Job(
      id: id,
      customerId: 'cust1',
      serviceId: 'wash',
      serviceTitle: 'غسيل',
      status: status,
      matchingMode: MatchingMode.quotes,
      commissionRate: 0.1,
      approxLocation: const GeoPoint(30.5, 47.7),
      createdAt: DateTime(2026, 3, 1),
    );
  }

  group('orders filter buckets', () {
    test('open done cancelled classifications stay mutually exclusive', () {
      final open = job(id: '1', status: JobStatus.dispatching);
      final offer = job(id: '2', status: JobStatus.offerPending);
      final done = job(id: '3', status: JobStatus.completed);
      final rated = job(id: '4', status: JobStatus.rated);
      final cancelled = job(id: '5', status: JobStatus.cancelled);
      final noTech = job(id: '6', status: JobStatus.noTechnician);

      expect(jobIsOpen(open) && !jobIsDone(open) && !jobIsClosed(open), isTrue);
      expect(jobIsOpen(offer), isTrue);
      expect(jobIsDone(done) && !jobIsOpen(done), isTrue);
      expect(jobIsDone(rated), isTrue);
      expect(jobIsClosed(cancelled) && !jobIsOpen(cancelled), isTrue);
      expect(jobIsClosed(noTech), isTrue);
    });

    test('OrdersFilter enum covers expected views', () {
      expect(OrdersFilter.values, containsAll([
        OrdersFilter.all,
        OrdersFilter.open,
        OrdersFilter.done,
        OrdersFilter.cancelled,
      ]));
    });
  });

  group('dispatch messaging', () {
    test('failed dispatch message is customer-facing and stable', () {
      expect(
        AppStrings.jobCreatedDispatchFailed,
        contains('تم إنشاء الطلب'),
      );
      expect(
        AppStrings.jobCreatedDispatchFailed,
        contains('تعذر بدء المطابقة'),
      );
    });
  });
}
