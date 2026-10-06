import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/geo.dart';

void main() {
  group('haversineKm', () {
    test('same point is zero', () {
      expect(haversineKm(30.5, 47.8, 30.5, 47.8), closeTo(0, 0.001));
    });

    test('basra center to nearby point is within city scale', () {
      final km = haversineKm(
        AppConstants.defaultLat,
        AppConstants.defaultLng,
        AppConstants.defaultLat + 0.05,
        AppConstants.defaultLng,
      );
      expect(km, greaterThan(4));
      expect(km, lessThan(8));
    });
  });

  group('isWithinRadiusKm', () {
    test('radius zero always true', () {
      expect(
        isWithinRadiusKm(
          pointLat: 0,
          pointLng: 0,
          centerLat: 10,
          centerLng: 10,
          radiusKm: 0,
        ),
        isTrue,
      );
    });

    test('point inside maxMatchKm', () {
      expect(
        isWithinRadiusKm(
          pointLat: AppConstants.defaultLat + 0.01,
          pointLng: AppConstants.defaultLng,
          centerLat: AppConstants.defaultLat,
          centerLng: AppConstants.defaultLng,
          radiusKm: AppConstants.maxMatchKm,
        ),
        isTrue,
      );
    });

    test('far point outside maxMatchKm', () {
      expect(
        isWithinRadiusKm(
          pointLat: AppConstants.defaultLat + 1.0,
          pointLng: AppConstants.defaultLng,
          centerLat: AppConstants.defaultLat,
          centerLng: AppConstants.defaultLng,
          radiusKm: AppConstants.maxMatchKm,
        ),
        isFalse,
      );
    });

    test('parts match uses wider radius', () {
      expect(
        isWithinRadiusKm(
          pointLat: AppConstants.defaultLat + 0.5,
          pointLng: AppConstants.defaultLng,
          centerLat: AppConstants.defaultLat,
          centerLng: AppConstants.defaultLng,
          radiusKm: AppConstants.maxPartsMatchKm,
        ),
        isTrue,
      );
    });
  });

  group('approximate', () {
    test('rounds to approxPrecision grid', () {
      final exact = const GeoPoint(30.5085123, 47.7830456);
      final approx = approximate(exact);
      final p = AppConstants.approxPrecision;
      expect(approx.latitude, (exact.latitude * p).round() / p);
      expect(approx.longitude, (exact.longitude * p).round() / p);
    });
  });
}
