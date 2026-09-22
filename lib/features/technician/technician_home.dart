import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/features/shared/osm_map.dart';
import 'package:barrr/features/technician/offer_overlay.dart';
import 'package:barrr/features/technician/tech_job_panel.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';
import 'package:barrr/models/wallet_entry.dart';
import 'package:barrr/services/user_repository.dart';

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
  CityZone? _zone;

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
    final zone = await scope.settings.getActiveCity();
    final fallback = zone != null
        ? LatLng(zone.centerLat, zone.centerLng)
        : const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    _me = await scope.location.currentOrDefault(fallback: fallback);
    _zone = zone;
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
    final result = await scope.users.setOnline(widget.profile.id, value);
    if (!value) {
      _posSub?.cancel();
      return;
    }
    if (!result.ok && mounted) {
      final message = switch (result.block) {
        OnlineBlock.rejected => 'تم رفض طلب الانضمام. راجع الإدارة.',
        OnlineBlock.lowBalance =>
          'رصيدك ${result.balance.toStringAsFixed(0)} د.ع والحد الأدنى ${result.minBalance.toStringAsFixed(0)} د.ع',
        OnlineBlock.pending || OnlineBlock.none => AppStrings.pendingVerify,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                final markers = <Marker>[
                  pinMarker(_me, color: Colors.green),
                  if (job != null)
                    pinMarker(
                      LatLng(job.displayLocation.latitude, job.displayLocation.longitude),
                    ),
                ];
                final circles = <CircleMarker>[
                  if (_zone != null)
                    coverageCircle(
                      centerLat: _zone!.centerLat,
                      centerLng: _zone!.centerLng,
                      radiusKm: _zone!.radiusKm,
                    ),
                ];
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
                      OsmMap(
                        center: _me,
                        zoom: 14,
                        markers: markers,
                        circles: circles,
                      ),
                      if (_zone != null)
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: Chip(
                              avatar: const Icon(Icons.place_outlined, size: 18),
                              label: Text(AppStrings.coverageLabel(_zone!.nameAr)),
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StreamBuilder(
                                stream: scope.settings.watchSettings(),
                                builder: (context, settingsSnap) {
                                  final min = settingsSnap.data?.minWalletBalance ??
                                      AppConstants.minWalletBalance;
                                  return Card(
                                    child: SwitchListTile(
                                      title: Text(
                                        me.isOnline ? AppStrings.online : AppStrings.offline,
                                      ),
                                      subtitle: Text(
                                        me.verificationStatus == VerificationStatus.rejected &&
                                                !me.isApproved
                                            ? 'تم رفض طلب الانضمام. راجع الإدارة.'
                                            : me.isApproved
                                                ? scope.users.walletHint(me, minBalance: min)
                                                : AppStrings.pendingVerify,
                                      ),
                                      value: me.isOnline,
                                      onChanged: _toggleOnline,
                                    ),
                                  );
                                },
                              ),
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.account_balance_wallet_outlined),
                                  title: Text(
                                    '${AppStrings.wallet}: ${me.walletBalance.toStringAsFixed(0)} د.ع',
                                  ),
                                  subtitle: const Text(AppStrings.walletAdminNote),
                                  trailing: TextButton(
                                    onPressed: () => _showHistory(me.id),
                                    child: const Text(AppStrings.walletHistory),
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

  Future<void> _showHistory(String uid) async {
    final scope = AppScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 420,
            child: StreamBuilder<List<WalletEntry>>(
              stream: scope.users.watchWalletEntries(uid),
              builder: (context, snap) {
                final rows = snap.data ?? const <WalletEntry>[];
                if (snap.connectionState == ConnectionState.waiting && rows.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (rows.isEmpty) {
                  return const Center(child: Text('لا توجد حركات بعد.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = rows[i];
                    final sign = e.signedAmount >= 0 ? '+' : '';
                    return ListTile(
                      title: Text(e.typeLabel),
                      subtitle: Text(e.note.isEmpty ? e.typeLabel : e.note),
                      trailing: Text('$sign${e.signedAmount.toStringAsFixed(0)}'),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
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
