import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/geo.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/features/customer/job_status_panel.dart';
import 'package:barrr/features/customer/service_sheet.dart';
import 'package:barrr/features/shared/osm_map.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key, required this.profile});

  final AppUser profile;

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  final _map = MapController();
  LatLng _pin = const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
  bool _ready = false;
  Timer? _timeoutWatch;
  CityZone? _zone;
  double _zoom = 12;

  var _locStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_locStarted) return;
    _locStarted = true;
    _initLocation();
  }

  Future<void> _initLocation() async {
    final scope = AppScope.of(context);
    final settings = await scope.settings.getSettings();
    final zone = await scope.settings.getActiveCity();
    final saved = widget.profile.geo;
    final fallback = saved != null
        ? LatLng(saved.latitude, saved.longitude)
        : zone != null
            ? LatLng(zone.centerLat, zone.centerLng)
            : const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    final loc = await scope.location.currentOrDefault(fallback: fallback);
    if (!mounted) return;
    setState(() {
      _zone = zone;
      _zoom = settings.defaultZoom;
      _pin = loc;
      _ready = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _map.move(loc, settings.defaultZoom);
    });
  }

  @override
  void dispose() {
    _timeoutWatch?.cancel();
    super.dispose();
  }

  bool _pinInZone() {
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

  Future<void> _confirmAndRequest(Job? active) async {
    if (active != null) return;
    if (!_pinInZone()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.outsideCoverage)),
      );
      return;
    }
    final service = await showServiceSheet(context);
    if (service == null || !mounted) return;
    final scope = AppScope.of(context);
    final geo = GeoPoint(_pin.latitude, _pin.longitude);
    final zoneName = _zone?.nameAr ?? '';
    final addressLabel = zoneName.isEmpty
        ? '${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)}'
        : '$zoneName (${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)})';
    await scope.users.setAddressAndGeo(
      widget.profile.id,
      address: widget.profile.address.trim().isEmpty
          ? addressLabel
          : widget.profile.address,
      geo: geo,
    );
    final jobId = await scope.jobs.createJob(
      customerId: widget.profile.id,
      serviceId: service.id,
      serviceTitle: service.titleAr,
      exact: geo,
      isEmergency: service.isEmergency,
      commissionRate: service.commissionRate,
    );
    await scope.dispatch.dispatch(jobId);
  }

  void _watchTimeout(Job? job, BuildContext context) {
    _timeoutWatch?.cancel();
    if (job == null || job.status != JobStatus.offerPending || job.expiresAt == null) {
      return;
    }
    final wait = job.expiresAt!.difference(DateTime.now()) + const Duration(seconds: 2);
    if (wait.isNegative) {
      AppScope.of(context).dispatch.onWindowExpired(job.id);
      return;
    }
    _timeoutWatch = Timer(wait, () {
      AppScope.of(context).dispatch.onWindowExpired(job.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return StreamBuilder<CityZone?>(
      stream: scope.settings.watchActiveCity(),
      builder: (context, zoneSnap) {
        final zone = zoneSnap.data ?? _zone;
        if (zoneSnap.hasData) _zone = zone;
        return StreamBuilder<Job?>(
          stream: scope.jobs.watchActiveForCustomer(widget.profile.id),
          builder: (context, snap) {
            final job = snap.data;
            _watchTimeout(job, context);
            final markers = <Marker>[
              if (job != null)
                pinMarker(
                  LatLng(job.displayLocation.latitude, job.displayLocation.longitude),
                  color: Colors.blueAccent,
                ),
            ];
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
                title: const Text(AppStrings.appName),
                actions: [
                  IconButton(
                    onPressed: () => scope.auth.signOut(),
                    icon: const Icon(Icons.logout),
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
                      markers: markers,
                      onPositionChanged: job == null ? (c) => _pin = c : null,
                    ),
                  if (_ready && job == null)
                    const IgnorePointer(
                      child: Center(
                        child: Icon(Icons.location_on, color: Colors.redAccent, size: 42),
                      ),
                    ),
                  if (job == null)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (zone != null)
                              Chip(
                                avatar: const Icon(Icons.place_outlined, size: 18),
                                label: Text(AppStrings.coverageLabel(zone.nameAr)),
                              ),
                            const SizedBox(height: 6),
                            const Chip(label: Text(AppStrings.pickLocation)),
                          ],
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: job == null
                        ? SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: FilledButton(
                                onPressed: () => _confirmAndRequest(job),
                                child: const Text(AppStrings.confirmLocation),
                              ),
                            ),
                          )
                        : CustomerJobPanel(job: job, me: widget.profile),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
