import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/services/location_service.dart';

/// خريطة OpenStreetMap مشتركة (بدون مفتاح).
class OsmMap extends StatefulWidget {
  const OsmMap({
    super.key,
    required this.center,
    this.zoom = 12,
    this.mapController,
    this.onPositionChanged,
    this.onLocated,
    this.circles = const [],
    this.markers = const [],
    this.interactive = true,
    this.onTap,
    this.showMyLocation = true,
  });

  final LatLng center;
  final double zoom;
  final MapController? mapController;
  final void Function(LatLng center)? onPositionChanged;
  final void Function(LatLng point)? onLocated;
  final List<CircleMarker> circles;
  final List<Marker> markers;
  final bool interactive;
  final void Function(LatLng point)? onTap;
  final bool showMyLocation;

  @override
  State<OsmMap> createState() => _OsmMapState();
}

class _OsmMapState extends State<OsmMap> {
  MapController? _owned;
  var _locating = false;

  MapController get _controller => widget.mapController ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.mapController == null) _owned = MapController();
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  Future<void> _goToMe() async {
    setState(() => _locating = true);
    final result = await LocationService().currentWithStatus(fallback: widget.center);
    if (!mounted) return;
    setState(() => _locating = false);
    if (result.outcome != LocationOutcome.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تحديد موقعك الحالي')),
      );
      return;
    }
    _controller.move(result.latLng, 16);
    widget.onLocated?.call(result.latLng);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            interactionOptions: InteractionOptions(
              flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
            onTap: widget.onTap == null ? null : (_, point) => widget.onTap!(point),
            onPositionChanged: (pos, hasGesture) {
              // أثناء السحب لا نُبلّغ الأب (يتجنّب setState المتكرر).
              // عند انتهاء الحركة hasGesture=false فنُرسل المركز النهائي.
              if (hasGesture || widget.onPositionChanged == null) return;
              widget.onPositionChanged!(pos.center);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.barrr.barrr',
            ),
            if (widget.circles.isNotEmpty) CircleLayer(circles: widget.circles),
            if (widget.markers.isNotEmpty) MarkerLayer(markers: widget.markers),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap'),
            ),
          ],
        ),
        if (widget.interactive && widget.showMyLocation)
          Positioned(
            top: 76,
            left: 12,
            child: Material(
              color: Colors.white,
              elevation: 3,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'موقعي الحالي',
                onPressed: _locating ? null : _goToMe,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
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
    color: const Color(0x22F59E0B),
    borderColor: const Color(0xFFF59E0B),
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
