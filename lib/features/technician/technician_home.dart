import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/features/technician/offer_overlay.dart';
import 'package:barrr/features/technician/tech_job_panel.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';

class TechnicianHome extends StatefulWidget {
  const TechnicianHome({super.key, required this.profile});

  final AppUser profile;

  @override
  State<TechnicianHome> createState() => _TechnicianHomeState();
}

class _TechnicianHomeState extends State<TechnicianHome> {
  StreamSubscription? _posSub;
  LatLng _me = const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
  JobOffer? _incoming;

  var _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    _boot();
  }

  Future<void> _boot() async {
    final scope = AppScope.of(context);
    _me = await scope.location.currentOrDefault();
    if (widget.profile.isOnline) _startTracking();
    if (mounted) setState(() {});
  }

  void _startTracking() {
    _posSub?.cancel();
    final scope = AppScope.of(context);
    _posSub = scope.location.track().listen((p) {
      _me = LatLng(p.latitude, p.longitude);
      scope.users.setGeo(widget.profile.id, GeoPoint(p.latitude, p.longitude));
      if (mounted) setState(() {});
    });
    scope.users.setGeo(widget.profile.id, GeoPoint(_me.latitude, _me.longitude));
  }

  Future<void> _toggleOnline(bool value) async {
    final scope = AppScope.of(context);
    final ok = await scope.users.setOnline(widget.profile.id, value);
    if (!value) {
      _posSub?.cancel();
      return;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يلزم التوثيق ورصيد محفظة كافٍ لاستقبال الطلبات')),
      );
      return;
    }
    _startTracking();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return StreamBuilder<AppUser?>(
      stream: scope.users.watch(widget.profile.id),
      builder: (context, profileSnap) {
        final me = profileSnap.data ?? widget.profile;
        return StreamBuilder<Job?>(
          stream: scope.jobs.watchActiveForTechnician(me.id),
          builder: (context, jobSnap) {
            final job = jobSnap.data;
            return StreamBuilder<List<JobOffer>>(
              stream: scope.jobs.watchPendingOffers(me.id),
              builder: (context, offerSnap) {
                final offers = offerSnap.data ?? const <JobOffer>[];
                final live = offers.where((o) => o.remainingSeconds() > 0).toList();
                if (_incoming == null && live.isNotEmpty && job == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _incoming = live.first);
                  });
                }
                final markers = <Marker>{
                  Marker(
                    markerId: const MarkerId('me'),
                    position: _me,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  ),
                };
                if (job != null) {
                  final loc = job.displayLocation;
                  markers.add(
                    Marker(
                      markerId: const MarkerId('customer'),
                      position: LatLng(loc.latitude, loc.longitude),
                    ),
                  );
                }
                return Scaffold(
                  appBar: AppBar(
                    title: Text(me.name.isEmpty ? AppStrings.technician : me.name),
                    actions: [
                      IconButton(
                        onPressed: () => _editServices(me),
                        icon: const Icon(Icons.handyman_outlined),
                      ),
                      IconButton(
                        onPressed: () => scope.auth.signOut(),
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                  body: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(target: _me, zoom: 14),
                        myLocationEnabled: true,
                        markers: markers,
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Card(
                                child: SwitchListTile(
                                  title: Text(me.isOnline ? AppStrings.online : AppStrings.offline),
                                  subtitle: Text(
                                    me.verified
                                        ? scope.users.walletHint(me)
                                        : AppStrings.pendingVerify,
                                  ),
                                  value: me.isOnline,
                                  onChanged: _toggleOnline,
                                ),
                              ),
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.account_balance_wallet_outlined),
                                  title: Text('${AppStrings.wallet}: ${me.walletBalance.toStringAsFixed(0)} د.ع'),
                                  subtitle: const Text(AppStrings.cashNote),
                                  trailing: TextButton(
                                    onPressed: () => _topUp(me.id),
                                    child: const Text(AppStrings.topUp),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (job != null)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: TechJobPanel(job: job, me: me),
                        ),
                      if (_incoming != null && job == null)
                        OfferOverlay(
                          offer: _incoming!,
                          technicianName: me.name,
                          onDone: () => setState(() => _incoming = null),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _topUp(String uid) async {
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.topUp),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ (د.ع)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('شحن')),
        ],
      ),
    );
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    amount.dispose();
    if (ok == true && value != null && value > 0) {
      await AppScope.of(context).users.topUpWallet(uid, value);
    }
  }

  Future<void> _editServices(AppUser me) async {
    final selected = {...me.serviceIds};
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(AppStrings.myServices),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in seedServices)
                        FilterChip(
                          label: Text(s.titleAr),
                          selected: selected.contains(s.id),
                          onSelected: (_) {
                            setLocal(() {
                              if (selected.contains(s.id)) {
                                selected.remove(s.id);
                              } else {
                                selected.add(s.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      await AppScope.of(context).users.setServiceIds(me.id, selected.toList());
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('حفظ'),
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
