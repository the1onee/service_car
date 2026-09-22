import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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

  Future<LatLng> currentOrDefault({LatLng? fallback}) async {
    final def = fallback ??
        const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    try {
      final ok = await ensurePermission();
      if (!ok) return def;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return def;
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
