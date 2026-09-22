import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/core/constants.dart';

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthKm = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthKm * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
}

/// هل النقطة داخل دائرة المركز بنصف قطر [radiusKm]؟
bool isWithinRadiusKm({
  required double pointLat,
  required double pointLng,
  required double centerLat,
  required double centerLng,
  required double radiusKm,
}) {
  if (radiusKm <= 0) return true;
  return haversineKm(pointLat, pointLng, centerLat, centerLng) <= radiusKm;
}

GeoPoint approximate(GeoPoint exact) {
  final p = AppConstants.approxPrecision;
  return GeoPoint(
    (exact.latitude * p).round() / p,
    (exact.longitude * p).round() / p,
  );
}

double _rad(double degrees) => degrees * math.pi / 180.0;
