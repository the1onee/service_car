import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/geo.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/features/shared/osm_map.dart';
import 'package:barrr/models/app_settings.dart';

class AddressPickResult {
  const AddressPickResult({
    required this.latLng,
    required this.label,
    this.zone,
  });

  final LatLng latLng;
  final String label;
  final CityZone? zone;

  GeoPoint get geo => GeoPoint(latLng.latitude, latLng.longitude);
}

Future<AddressPickResult?> pickAddressOnMap(
  BuildContext context, {
  LatLng? initial,
  String title = AppStrings.pickLocation,
}) {
  return Navigator.of(context).push<AddressPickResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AddressMapPage(initial: initial, title: title),
    ),
  );
}

class _AddressMapPage extends StatefulWidget {
  const _AddressMapPage({this.initial, required this.title});

  final LatLng? initial;
  final String title;

  @override
  State<_AddressMapPage> createState() => _AddressMapPageState();
}

class _AddressMapPageState extends State<_AddressMapPage> {
  final _map = MapController();
  LatLng _pin = const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
  CityZone? _zone;
  double _zoom = 12;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final scope = AppScope.of(context);
    final settings = await scope.settings.getSettings();
    final zone = await scope.settings.getActiveCity();
    final fallback = widget.initial ??
        (zone != null
            ? LatLng(zone.centerLat, zone.centerLng)
            : const LatLng(AppConstants.defaultLat, AppConstants.defaultLng));
    final loc = widget.initial ??
        await scope.location.currentOrDefault(fallback: fallback);
    if (!mounted) return;
    setState(() {
      _zone = zone;
      _zoom = settings.defaultZoom;
      _pin = loc;
      _ready = true;
    });
  }

  bool _inZone() {
    final z = _zone;
    if (z == null) return true;
    return isWithinRadiusKm(
      pointLat: _pin.latitude,
      pointLng: _pin.longitude,
      centerLat: z.centerLat,
      centerLng: z.centerLng,
      radiusKm: z.radiusKm,
    );
  }

  void _confirm() {
    try {
      _pin = _map.camera.center;
    } catch (_) {}
    if (!_inZone()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.outsideCoverage)),
      );
      return;
    }
    final z = _zone;
    final label = z != null
        ? '${z.nameAr} (${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)})'
        : '${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)}';
    Navigator.pop(
      context,
      AddressPickResult(latLng: _pin, label: label, zone: z),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zone = _zone;
    final circles = <CircleMarker>[
      if (zone != null)
        coverageCircle(
          centerLat: zone.centerLat,
          centerLng: zone.centerLng,
          radiusKm: zone.radiusKm,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _ready ? _confirm : null,
            child: const Text(AppStrings.confirmLocation),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_ready)
            const Center(child: CircularProgressIndicator())
          else
            OsmMap(
              mapController: _map,
              center: _pin,
              zoom: _zoom,
              circles: circles,
              onTap: (point) {
                setState(() => _pin = point);
                _map.move(point, _zoom);
              },
              onPositionChanged: (c) => setState(() => _pin = c),
            ),
          if (_ready)
            const IgnorePointer(
              child: Center(
                child: Icon(Icons.location_on, color: Colors.redAccent, size: 42),
              ),
            ),
          if (zone != null)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Chip(
                  avatar: const Icon(Icons.place_outlined, size: 18),
                  label: Text(AppStrings.coverageLabel(zone.nameAr)),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _ready ? _confirm : null,
                  child: const Text(AppStrings.confirmLocation),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
