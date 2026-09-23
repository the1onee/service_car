import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/constants.dart';

enum LocationOutcome { ok, servicesDisabled, denied, deniedForever, error }

class LocationResult {
  const LocationResult({required this.latLng, required this.outcome});

  final LatLng latLng;
  final LocationOutcome outcome;
}

class LocationService {
  Future<LocationOutcome> checkPermissionOutcome() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return LocationOutcome.servicesDisabled;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationOutcome.deniedForever;
    }
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return LocationOutcome.ok;
    }
    return LocationOutcome.denied;
  }

  Future<bool> ensurePermission() async {
    return (await checkPermissionOutcome()) == LocationOutcome.ok;
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<LatLng> currentOrDefault({LatLng? fallback}) async {
    final result = await currentWithStatus(fallback: fallback);
    return result.latLng;
  }

  Future<LocationResult> currentWithStatus({LatLng? fallback}) async {
    final def = fallback ??
        const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    try {
      final outcome = await checkPermissionOutcome();
      if (outcome != LocationOutcome.ok) {
        return LocationResult(latLng: def, outcome: outcome);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LocationResult(
        latLng: LatLng(p.latitude, p.longitude),
        outcome: LocationOutcome.ok,
      );
    } catch (_) {
      return LocationResult(latLng: def, outcome: LocationOutcome.error);
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
