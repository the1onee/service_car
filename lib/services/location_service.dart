import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:barrr/core/constants.dart';

class LocationService {
  Future<bool> ensurePermission() async {
    var enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LatLng> currentOrDefault() async {
    try {
      final ok = await ensurePermission();
      if (!ok) {
        return const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    }
  }

  Stream<Position> track() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    );
  }
}
