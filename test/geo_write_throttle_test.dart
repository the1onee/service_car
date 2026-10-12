import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/services/geo_write_throttle.dart';

void main() {
  test('force writes then blocks near duplicates until interval', () {
    final t = GeoWriteThrottle(
      minInterval: const Duration(seconds: 30),
      minDistanceMeters: 40,
    );
    final a = const GeoPoint(30.5, 47.8);
    expect(t.shouldWrite(a, force: true), isTrue);
    expect(t.shouldWrite(a), isFalse);
  });

  test('allows write after enough distance even mid-interval once interval passed', () {
    final t = GeoWriteThrottle(
      minInterval: Duration.zero,
      minDistanceMeters: 40,
    );
    final a = const GeoPoint(30.5, 47.8);
    expect(t.shouldWrite(a, force: true), isTrue);
    // ~0.001 deg lat ≈ 111m
    final b = const GeoPoint(30.501, 47.8);
    expect(t.shouldWrite(b), isTrue);
  });
}
