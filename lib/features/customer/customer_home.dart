import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/features/customer/job_status_panel.dart';
import 'package:barrr/features/customer/service_sheet.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key, required this.profile});

  final AppUser profile;

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  GoogleMapController? _map;
  LatLng _pin = const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
  bool _ready = false;
  Timer? _timeoutWatch;

  var _locStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_locStarted) return;
    _locStarted = true;
    _initLocation();
  }

  Future<void> _initLocation() async {
    final loc = await AppScope.of(context).location.currentOrDefault();
    if (!mounted) return;
    setState(() {
      _pin = loc;
      _ready = true;
    });
    _map?.animateCamera(CameraUpdate.newLatLngZoom(loc, 15));
  }

  @override
  void dispose() {
    _timeoutWatch?.cancel();
    super.dispose();
  }

  Future<void> _confirmAndRequest(Job? active) async {
    if (active != null) return;
    final service = await showServiceSheet(context);
    if (service == null || !mounted) return;
    final scope = AppScope.of(context);
    final jobId = await scope.jobs.createJob(
      customerId: widget.profile.id,
      serviceId: service.id,
      serviceTitle: service.titleAr,
      exact: GeoPoint(_pin.latitude, _pin.longitude),
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
    return StreamBuilder<Job?>(
      stream: scope.jobs.watchActiveForCustomer(widget.profile.id),
      builder: (context, snap) {
        final job = snap.data;
        _watchTimeout(job, context);
        final markers = <Marker>{
          Marker(markerId: const MarkerId('pin'), position: _pin),
        };
        if (job != null) {
          final loc = job.displayLocation;
          markers.add(
            Marker(
              markerId: const MarkerId('job'),
              position: LatLng(loc.latitude, loc.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ),
          );
        }
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
              if (_ready)
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _pin, zoom: 15),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (c) => _map = c,
                  onCameraMove: (pos) {
                    if (job == null) _pin = pos.target;
                  },
                  markers: markers,
                )
              else
                const Center(child: CircularProgressIndicator()),
              if (job == null)
                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Chip(label: Text(AppStrings.pickLocation)),
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
  }
}
