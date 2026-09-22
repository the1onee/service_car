import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/constants.dart';

/// خريطة OpenStreetMap مشتركة (بدون مفتاح).
class OsmMap extends StatelessWidget {
  const OsmMap({
    super.key,
    required this.center,
    this.zoom = 12,
    this.mapController,
    this.onPositionChanged,
    this.circles = const [],
    this.markers = const [],
    this.interactive = true,
  });

  final LatLng center;
  final double zoom;
  final MapController? mapController;
  final void Function(LatLng center)? onPositionChanged;
  final List<CircleMarker> circles;
  final List<Marker> markers;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onPositionChanged: (pos, hasGesture) {
          if (!hasGesture || onPositionChanged == null) return;
          final c = pos.center;
          onPositionChanged!(c);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.barrr.barrr',
        ),
        if (circles.isNotEmpty) CircleLayer(circles: circles),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap'),
        ),
      ],
    );
  }
}

CircleMarker coverageCircle({
  required double centerLat,
  required double centerLng,
  required double radiusKm,
}) {
  return CircleMarker(
    point: LatLng(centerLat, centerLng),
    radius: radiusKm * 1000,
    useRadiusInMeter: true,
    color: const Color(0x220F766E),
    borderColor: const Color(0xFF0F766E),
    borderStrokeWidth: 2,
  );
}

Marker pinMarker(LatLng point, {Color color = Colors.redAccent}) {
  return Marker(
    point: point,
    width: 44,
    height: 44,
    alignment: Alignment.topCenter,
    child: Icon(Icons.location_on, color: color, size: 40),
  );
}

LatLng defaultBasra() =>
    const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
