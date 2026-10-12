import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// يحدّ من كتابات `setGeo` إلى Firestore (وقت + مسافة).
class GeoWriteThrottle {
  GeoWriteThrottle({
    this.minInterval = const Duration(seconds: 30),
    this.minDistanceMeters = 40,
  });

  final Duration minInterval;
  final double minDistanceMeters;

  DateTime? _lastWriteAt;
  GeoPoint? _lastWritten;

  /// أول كتابة أو تجاوز الحد الزمني والمسافة.
  bool shouldWrite(GeoPoint next, {bool force = false}) {
    if (force) {
      _remember(next);
      return true;
    }
    final last = _lastWritten;
    final at = _lastWriteAt;
    if (last == null || at == null) {
      _remember(next);
      return true;
    }
    final elapsed = DateTime.now().difference(at);
    if (elapsed < minInterval) return false;
    final meters = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      next.latitude,
      next.longitude,
    );
    if (meters < minDistanceMeters) return false;
    _remember(next);
    return true;
  }

  void _remember(GeoPoint next) {
    _lastWritten = next;
    _lastWriteAt = DateTime.now();
  }

  void reset() {
    _lastWriteAt = null;
    _lastWritten = null;
  }
}
