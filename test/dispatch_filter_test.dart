import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/services/dispatch_filter.dart';

// ─── helpers ────────────────────────────────────────────────────────────────

DispatchCandidate _candidate({
  String id = 'c1',
  bool online = true,
  double km = 5.0,
  String name = 'فني',
  double rating = 5.0,
  bool verified = true,
  double wallet = 20000,
  List<String> serviceIds = const [],
  List<String> vehicleTypeIds = const [],
  bool isWorkshop = false,
  String oilWorkshopTier = '',
  String specialtyId = '',
  List<String> specialtyIds = const [],
  String specialtyAr = '',
}) =>
    DispatchCandidate(
      id: id,
      online: online,
      km: km,
      name: name,
      rating: rating,
      verified: verified,
      wallet: wallet,
      serviceIds: serviceIds,
      vehicleTypeIds: vehicleTypeIds,
      isWorkshop: isWorkshop,
      oilWorkshopTier: oilWorkshopTier,
      specialtyId: specialtyId,
      specialtyIds: specialtyIds,
      specialtyAr: specialtyAr,
    );

DispatchFilter _filter({
  bool isPartsOrder = false,
  bool isOilOrder = false,
  bool isPaintOrder = false,
  bool isEmergency = false,
  String serviceId = 'svc1',
  String? vehicleTypeId,
  String specialtyId = '',
  double minWallet = 10000,
  Set<String> usedProviderIds = const {},
}) =>
    DispatchFilter(
      isPartsOrder: isPartsOrder,
      isOilOrder: isOilOrder,
      isPaintOrder: isPaintOrder,
      isEmergency: isEmergency,
      serviceId: serviceId,
      vehicleTypeId: vehicleTypeId,
      specialtyId: specialtyId,
      minWallet: minWallet,
      usedProviderIds: usedProviderIds,
    );

// ─── tests ──────────────────────────────────────────────────────────────────

void main() {
  group('filterAndRankCandidates', () {
    test('returns empty list when no candidates provided', () {
      final result = filterAndRankCandidates(
        all: [],
        filter: _filter(),
      );
      expect(result, isEmpty);
    });

    test('excludes unverified candidates', () {
      final result = filterAndRankCandidates(
        all: [_candidate(verified: false)],
        filter: _filter(),
      );
      expect(result, isEmpty);
    });

    test('excludes offline candidates', () {
      final result = filterAndRankCandidates(
        all: [_candidate(online: false)],
        filter: _filter(),
      );
      expect(result, isEmpty);
    });

    test('excludes candidates with low wallet (non-parts, non-workshop)', () {
      final result = filterAndRankCandidates(
        all: [_candidate(wallet: 500, isWorkshop: false)],
        filter: _filter(minWallet: 10000),
      );
      expect(result, isEmpty);
    });

    test('includes workshops even with low wallet for non-parts orders', () {
      // الورش (isWorkshop) لا تُفلتر بالرصيد في الطلبات غير قطع الغيار
      final result = filterAndRankCandidates(
        all: [_candidate(wallet: 0, isWorkshop: true)],
        filter: _filter(minWallet: 10000, isPartsOrder: false),
      );
      expect(result, hasLength(1));
    });

    test('parts orders skip wallet check entirely', () {
      final result = filterAndRankCandidates(
        all: [_candidate(wallet: 0, isWorkshop: false)],
        filter: _filter(isPartsOrder: true),
      );
      expect(result, hasLength(1));
    });

    test('excludes already-used provider IDs', () {
      final result = filterAndRankCandidates(
        all: [_candidate(id: 'used1')],
        filter: _filter(usedProviderIds: {'used1'}),
      );
      expect(result, isEmpty);
    });

    test('filters by serviceId when candidate has serviceIds', () {
      final result = filterAndRankCandidates(
        all: [
          _candidate(id: 'match', serviceIds: ['svc1', 'svc2']),
          _candidate(id: 'no_match', serviceIds: ['svc3']),
        ],
        filter: _filter(serviceId: 'svc1'),
      );
      expect(result.map((c) => c.id), ['match']);
    });

    test('candidates with empty serviceIds pass service filter', () {
      final result = filterAndRankCandidates(
        all: [_candidate(serviceIds: [])],
        filter: _filter(serviceId: 'anything'),
      );
      expect(result, hasLength(1));
    });

    test('parts-order workshops skip service filter', () {
      final result = filterAndRankCandidates(
        all: [_candidate(isWorkshop: true, serviceIds: ['other'])],
        filter: _filter(isPartsOrder: true, serviceId: 'svc1'),
      );
      expect(result, hasLength(1));
    });

    test('excludes candidates beyond maxMatchKm', () {
      final farAway = _candidate(km: AppConstants.maxMatchKm + 1);
      final result = filterAndRankCandidates(
        all: [farAway],
        filter: _filter(),
      );
      expect(result, isEmpty);
    });

    test('parts orders use maxPartsMatchKm instead', () {
      final midRange =
          _candidate(km: AppConstants.maxMatchKm + 10); // > 25 but < 120
      final result = filterAndRankCandidates(
        all: [midRange],
        filter: _filter(isPartsOrder: true),
      );
      expect(result, hasLength(1));
    });

    test('excludes candidates beyond maxPartsMatchKm for parts', () {
      final tooFar = _candidate(km: AppConstants.maxPartsMatchKm + 1);
      final result = filterAndRankCandidates(
        all: [tooFar],
        filter: _filter(isPartsOrder: true),
      );
      expect(result, isEmpty);
    });

    test('filters by vehicleTypeId for non-workshop candidates', () {
      final result = filterAndRankCandidates(
        all: [
          _candidate(id: 'ok', vehicleTypeIds: ['sedan', 'suv']),
          _candidate(id: 'no', vehicleTypeIds: ['truck']),
        ],
        filter: _filter(vehicleTypeId: 'sedan'),
      );
      expect(result.map((c) => c.id), ['ok']);
    });

    test('workshops skip vehicleType filter', () {
      final result = filterAndRankCandidates(
        all: [_candidate(isWorkshop: true, vehicleTypeIds: ['truck'])],
        filter: _filter(vehicleTypeId: 'sedan'),
      );
      expect(result, hasLength(1));
    });

    test('specialty filter for parts orders', () {
      final result = filterAndRankCandidates(
        all: [
          _candidate(id: 'match', specialtyIds: ['sp1']),
          _candidate(id: 'no', specialtyIds: ['sp2']),
        ],
        filter: _filter(isPartsOrder: true, specialtyId: 'sp1'),
      );
      expect(result.map((c) => c.id), ['match']);
    });

    test('specialty filter skipped when specialtyId is empty', () {
      final result = filterAndRankCandidates(
        all: [
          _candidate(id: 'a', specialtyIds: ['sp1']),
          _candidate(id: 'b', specialtyIds: ['sp2']),
        ],
        filter: _filter(isPartsOrder: true, specialtyId: ''),
      );
      expect(result, hasLength(2));
    });

    test('results sorted by distance ascending', () {
      final result = filterAndRankCandidates(
        all: [
          _candidate(id: 'far', km: 20),
          _candidate(id: 'close', km: 2),
          _candidate(id: 'mid', km: 10),
        ],
        filter: _filter(),
      );
      expect(result.map((c) => c.id), ['close', 'mid', 'far']);
    });

    test('maxResults caps the output list', () {
      final many = List.generate(
        100,
        (i) => _candidate(id: 'c$i', km: i.toDouble()),
      );
      final result = filterAndRankCandidates(
        all: many,
        filter: _filter(),
        maxResults: 5,
      );
      expect(result, hasLength(5));
      expect(result.first.id, 'c0');
      expect(result.last.id, 'c4');
    });

    test('defaults to maxCandidatesPerDispatch when maxResults not set', () {
      // Keep all candidates inside maxMatchKm so distance filter does not shrink the list.
      final many = List.generate(
        100,
        (i) => _candidate(id: 'c$i', km: i * 0.1),
      );
      final result = filterAndRankCandidates(
        all: many,
        filter: _filter(),
      );
      expect(result, hasLength(AppConstants.maxCandidatesPerDispatch));
    });

    test('complex scenario: multiple filters combine correctly', () {
      final candidates = [
        // يمر كل الفلاتر
        _candidate(
          id: 'perfect',
          verified: true,
          wallet: 15000,
          km: 3,
          serviceIds: ['svc1'],
          vehicleTypeIds: ['sedan'],
        ),
        // غير معتمد
        _candidate(id: 'unverified', verified: false, km: 1),
        // رصيد منخفض
        _candidate(id: 'poor', wallet: 500, km: 2),
        // بعيد جداً
        _candidate(id: 'far', km: 999),
        // خدمة خاطئة
        _candidate(id: 'wrong_svc', serviceIds: ['svc99'], km: 4),
        // نوع مركبة خاطئ
        _candidate(id: 'wrong_vehicle', vehicleTypeIds: ['truck'], km: 5),
        // مستخدم سابقاً
        _candidate(id: 'used', km: 1),
      ];
      final result = filterAndRankCandidates(
        all: candidates,
        filter: _filter(
          serviceId: 'svc1',
          vehicleTypeId: 'sedan',
          usedProviderIds: {'used'},
          minWallet: 10000,
        ),
      );
      expect(result.map((c) => c.id), ['perfect']);
    });
  });
}
