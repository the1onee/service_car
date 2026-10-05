import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/orders_screen.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/oil_workshop/oil_offer_overlay.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/shared/osm_map.dart';
import 'package:barrr/features/technician/tech_job_panel.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';
import 'package:barrr/models/wallet_entry.dart';
import 'package:barrr/models/wallet_top_up.dart';
import 'package:barrr/services/fcm_service.dart';
import 'package:barrr/services/profile_photo_upload.dart';
import 'package:barrr/services/user_repository.dart';
import 'package:barrr/services/wallet_top_up_upload.dart';

part 'oil_workshop_wallet.part.dart';
part 'oil_workshop_account.part.dart';

/// لوحة ورشة الزيوت: استقبال العروض ودورة الزيارة المنزلية.
class OilWorkshopHome extends StatefulWidget {
  const OilWorkshopHome({super.key, required this.profile});

  final AppUser profile;

  @override
  State<OilWorkshopHome> createState() => _OilWorkshopHomeState();
}

class _OilWorkshopHomeState extends State<OilWorkshopHome> {
  StreamSubscription? _posSub;
  StreamSubscription<List<JobOffer>>? _offersSub;
  StreamSubscription<Job?>? _activeJobSub;
  late final ValueNotifier<LatLng> _meNotifier;
  JobOffer? _incoming;
  Job? _activeJob;
  CityZone? _zone;
  var _booted = false;
  var _tab = 0;
  var _dutyBusy = false;
  bool? _duty;
  String? _dutyHint;
  DateTime? _lastGeoWrite;
  VoidCallback? _fcmFocusListener;
  FcmService? _fcm;
  Stream<AppUser?>? _userStream;
  Stream<Job?>? _activeJobStream;
  Stream<List<Job>>? _recentJobsStream;

  @override
  void initState() {
    super.initState();
    _meNotifier = ValueNotifier(
      const LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    final uid = widget.profile.id;
    _userStream ??= scope.users.watch(uid);
    if (_booted) return;
    _booted = true;
    _activeJobSub = scope.jobs.watchActiveForTechnician(uid).listen((job) {
      if (!mounted) return;
      setState(() {
        if (job == null && _activeJob != null) {
          _incoming = null;
        }
        _activeJob = job;
      });
    });
    _offersSub = scope.jobs.watchPendingOffers(uid).listen((offers) {
      if (!mounted) return;
      final live = offers
          .where((o) => o.isOpenEnded || o.remainingSeconds() > 0)
          .toList();
      if (_incoming != null &&
          live.every((o) => o.id != _incoming!.id)) {
        setState(() => _incoming = null);
        return;
      }
      if (_incoming == null && live.isNotEmpty && _activeJob == null) {
        setState(() {
          _incoming = live.first;
          _tab = 0;
        });
      }
    });
    _fcm = scope.fcm;
    _fcmFocusListener = () {
      final id = scope.fcm.focusJobId.value;
      if (id == null || id.isEmpty || !mounted) return;
      setState(() => _tab = 0);
      scope.fcm.focusJobId.value = null;
    };
    scope.fcm.focusJobId.addListener(_fcmFocusListener!);
    _boot();
  }

  Stream<List<Job>> _ensureRecentJobs() {
    return _recentJobsStream ??=
        AppScope.of(context).jobs.watchRecentForTechnician(widget.profile.id);
  }

  Future<void> _boot() async {
    final scope = AppScope.of(context);
    final zone = await scope.settings.getActiveCity();
    final fallback = zone != null
        ? LatLng(zone.centerLat, zone.centerLng)
        : const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    final me = await scope.location.currentOrDefault(fallback: fallback);
    _meNotifier.value = me;
    _zone = zone;
    if (widget.profile.isOnline) _startTracking();
    if (mounted) setState(() {});
  }

  void _startTracking() {
    _posSub?.cancel();
    final scope = AppScope.of(context);
    _posSub = scope.location.track().listen((p) {
      final next = LatLng(p.latitude, p.longitude);
      _meNotifier.value = next;
      final now = DateTime.now();
      final due = _lastGeoWrite == null ||
          now.difference(_lastGeoWrite!) > const Duration(seconds: 8);
      if (!due) return;
      _lastGeoWrite = now;
      scope.users.setGeo(widget.profile.id, GeoPoint(p.latitude, p.longitude));
    });
    final me = _meNotifier.value;
    scope.users.setGeo(widget.profile.id, GeoPoint(me.latitude, me.longitude));
  }

  Future<void> _toggleOnline(bool value) async {
    if (_dutyBusy) return;
    setState(() {
      _dutyBusy = true;
      _duty = value;
      _dutyHint = null;
    });
    final scope = AppScope.of(context);
    try {
      final result = await scope.users.setOnline(widget.profile.id, value);
      if (!mounted) return;
      if (!value) {
        await _posSub?.cancel();
        _posSub = null;
        return;
      }
      if (!result.ok) {
        final message = switch (result.block) {
          OnlineBlock.rejected => 'تم رفض طلب الانضمام. راجع الإدارة.',
          OnlineBlock.lowBalance =>
            'رصيدك ${result.balance.toStringAsFixed(0)} د.ع والحد الأدنى لاستقبال الطلبات ${result.minBalance.toStringAsFixed(0)} د.ع',
          OnlineBlock.pending || OnlineBlock.none => AppStrings.pendingVerify,
        };
        setState(() {
          _duty = false;
          _dutyHint = message;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      final me = _meNotifier.value;
      await scope.users.setGeo(
        widget.profile.id,
        GeoPoint(me.latitude, me.longitude),
      );
      _lastGeoWrite = DateTime.now();
      _startTracking();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _duty = !value;
        _dutyHint = 'تعذر تغيير حالة الاتصال';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تغيير حالة الاتصال: $e')),
      );
    } finally {
      if (mounted) setState(() => _dutyBusy = false);
    }
  }

  @override
  void dispose() {
    if (_fcmFocusListener != null) {
      _fcm?.focusJobId.removeListener(_fcmFocusListener!);
    }
    _posSub?.cancel();
    _offersSub?.cancel();
    _activeJobSub?.cancel();
    _meNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FieldShell(
      tab: _tab,
      onTab: (i) => setState(() {
        if (i != _tab) {
          _activeJobStream = null;
          _recentJobsStream = null;
        }
        _tab = i;
      }),
      items: const [
        FieldNavItem(icon: Icons.home_rounded, label: 'الرئيسية'),
        FieldNavItem(icon: Icons.receipt_long_outlined, label: 'الطلبات'),
        FieldNavItem(
            icon: Icons.account_balance_wallet_outlined, label: 'المحفظة'),
        FieldNavItem(icon: Icons.person_outline_rounded, label: 'حسابي'),
      ],
      body: _buildTabBody(),
    );
  }

  Widget _buildTabBody() {
    final userStream = _userStream;
    if (userStream == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tab == 0) {
      _activeJobStream ??= AppScope.of(context)
          .jobs
          .watchActiveForTechnician(widget.profile.id);
    }
    final activeJobStream = _activeJobStream;
    return switch (_tab) {
      1 => _ordersTab(userStream, _ensureRecentJobs()),
      2 => _walletTab(userStream),
      3 => _accountTab(userStream),
      _ => _OilMapTab(
          profileId: widget.profile.id,
          fallbackProfile: widget.profile,
          zone: _zone,
          meListenable: _meNotifier,
          userStream: userStream,
          activeJobStream: activeJobStream!,
          dutyOverride: _duty,
          dutyBusy: _dutyBusy,
          dutyHint: _dutyHint,
          incoming: _incoming,
          onToggle: _toggleOnline,
          onClearIncoming: () => setState(() => _incoming = null),
          onLocated: (point) => _meNotifier.value = point,
        ),
    };
  }

  Widget _ordersTab(
    Stream<AppUser?> userStream,
    Stream<List<Job>> recentJobsStream,
  ) {
    return StreamBuilder<AppUser?>(
      stream: userStream,
      builder: (context, snap) {
        final me = snap.data ?? widget.profile;
        return OrdersScreen(
          stream: recentJobsStream,
          profile: me,
        );
      },
    );
  }

  Widget _walletTab(Stream<AppUser?> userStream) {
    return StreamBuilder<AppUser?>(
      stream: userStream,
      builder: (context, snap) {
        final me = snap.data ?? widget.profile;
        final online = _duty ?? me.isOnline;
        if (_duty != null && _duty == me.isOnline && !_dutyBusy) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _duty = null);
          });
        }
        return _WalletPage(
          me: me,
          online: online,
          dutyHint: _dutyHint,
          city: _zone?.nameAr,
          onToggle: _toggleOnline,
          onAccount: () => setState(() => _tab = 3),
        );
      },
    );
  }

  Widget _accountTab(Stream<AppUser?> userStream) {
    return StreamBuilder<AppUser?>(
      stream: userStream,
      builder: (context, snap) {
        return _AccountPage(
          me: snap.data ?? widget.profile,
          onOpenOrders: () => setState(() => _tab = 1),
          onOpenWallet: () => setState(() => _tab = 2),
        );
      },
    );
  }
}

class _OilMapTab extends StatelessWidget {
  const _OilMapTab({
    required this.profileId,
    required this.fallbackProfile,
    required this.zone,
    required this.meListenable,
    required this.userStream,
    required this.activeJobStream,
    required this.dutyOverride,
    required this.dutyBusy,
    required this.dutyHint,
    required this.incoming,
    required this.onToggle,
    required this.onClearIncoming,
    required this.onLocated,
  });

  final String profileId;
  final AppUser fallbackProfile;
  final CityZone? zone;
  final ValueNotifier<LatLng> meListenable;
  final Stream<AppUser?> userStream;
  final Stream<Job?> activeJobStream;
  final bool? dutyOverride;
  final bool dutyBusy;
  final String? dutyHint;
  final JobOffer? incoming;
  final Future<void> Function(bool value) onToggle;
  final VoidCallback onClearIncoming;
  final ValueChanged<LatLng> onLocated;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: userStream,
      builder: (context, profileSnap) {
        final me = profileSnap.data ?? fallbackProfile;
        final online = dutyOverride ?? me.isOnline;
        return StreamBuilder<Job?>(
          stream: activeJobStream,
          builder: (context, jobSnap) {
            final job = jobSnap.data;
            return Stack(
              children: [
                ValueListenableBuilder<LatLng>(
                  valueListenable: meListenable,
                  builder: (context, mePoint, _) {
                    final markers = <Marker>[
                      pinMarker(mePoint, color: AppColors.emerald),
                      if (job != null)
                        pinMarker(
                          LatLng(
                            job.displayLocation.latitude,
                            job.displayLocation.longitude,
                          ),
                          color: AppColors.amber,
                        ),
                    ];
                    final circles = <CircleMarker>[
                      if (zone != null)
                        coverageCircle(
                          centerLat: zone!.centerLat,
                          centerLng: zone!.centerLng,
                          radiusKm: zone!.radiusKm,
                        ),
                    ];
                    return Stack(
                      children: [
                        OsmMap(
                          center: mePoint,
                          zoom: 14,
                          markers: markers,
                          circles: circles,
                          onLocated: onLocated,
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: FieldTopBar(
                            city: zone?.nameAr,
                            caption: 'ورشة الزيوت',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusPill(
                                  label: online ? 'متصل' : 'غير متصل',
                                  color: online
                                      ? AppColors.emeraldDeep
                                      : AppColors.inkSoft,
                                  background: online
                                      ? AppColors.emeraldTint
                                      : AppColors.recessed,
                                ),
                                if (me.oilWorkshopTier != null) ...[
                                  const SizedBox(width: 4),
                                  StatusPill(
                                    label: me.oilWorkshopTierLabel,
                                    color: AppColors.amberDeep,
                                    background: AppColors.amberTint,
                                  ),
                                ],
                                NotificationsBellButton(uid: me.id),
                              ],
                            ),
                          ),
                        ),
                        if (job != null)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: TechJobPanel(job: job, me: me),
                          )
                        else
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: FieldCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            online
                                                ? 'متصل — بانتظار طلبات الزيت'
                                                : 'غير متصل',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            dutyHint ??
                                                'الرصيد ${formatIqd(me.walletBalance)}',
                                            style: TextStyle(
                                              color: dutyHint == null
                                                  ? AppColors.inkSoft
                                                  : AppColors.danger,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: online,
                                      onChanged: dutyBusy ? null : onToggle,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (incoming != null && job == null)
                  Positioned.fill(
                    child: OilOfferOverlay(
                      offer: incoming!,
                      workshopName: me.name,
                      onDone: onClearIncoming,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
