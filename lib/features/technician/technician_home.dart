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
import 'package:barrr/core/user_error.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/features/auth/add_phone_screen.dart';
import 'package:barrr/features/legal/privacy_view_screen.dart';
import 'package:barrr/features/legal/terms_view_screen.dart';
import 'package:barrr/features/support/support_screen.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/jobs/orders_screen.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/shared/osm_map.dart';
import 'package:barrr/features/technician/offer_overlay.dart';
import 'package:barrr/features/technician/tech_job_panel.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';
import 'package:barrr/models/service_item.dart';
import 'package:barrr/models/vehicle_type.dart';
import 'package:barrr/models/wallet_entry.dart';
import 'package:barrr/models/wallet_top_up.dart';
import 'package:barrr/services/fcm_service.dart';
import 'package:barrr/services/geo_write_throttle.dart';
import 'package:barrr/services/profile_photo_upload.dart';
import 'package:barrr/services/wallet_top_up_upload.dart';


part 'technician_wallet.part.dart';
part 'technician_account.part.dart';

class TechnicianHome extends StatefulWidget {
  const TechnicianHome({super.key, required this.profile});

  final AppUser profile;

  @override
  State<TechnicianHome> createState() => _TechnicianHomeState();
}

class _TechnicianHomeState extends State<TechnicianHome>
    with WidgetsBindingObserver {
  StreamSubscription? _posSub;
  StreamSubscription<List<JobOffer>>? _offersSub;
  StreamSubscription<Job?>? _activeJobSub;
  late final ValueNotifier<LatLng> _meNotifier;
  List<JobOffer> _liveOffers = const [];
  final Set<String> _closedOffers = {};
  Job? _activeJob;
  var _showOfferQueue = false;
  CityZone? _zone;
  var _booted = false;
  var _tab = 0;
  final _geoThrottle = GeoWriteThrottle();
  VoidCallback? _fcmFocusListener;
  FcmService? _fcm;
  Stream<AppUser?>? _userStream;
  Stream<Job?>? _activeJobStream;
  Stream<List<Job>>? _recentJobsStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _meNotifier = ValueNotifier(
      const LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_booted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _startTracking();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _stopTracking();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    final uid = widget.profile.id;
    // الملف الشخصي + العروض الواردة + الطلب النشط دائماً (لا تفويت عرض طارئ).
    _userStream ??= scope.users.watch(uid);
    if (_booted) return;
    _booted = true;
    _activeJobSub = scope.jobs.watchActiveForTechnician(uid).listen((job) {
      if (!mounted) return;
      setState(() {
        _activeJob = job;
        if (jobBlocksIncomingOffers(job)) {
          _showOfferQueue = false;
        }
      });
    });
    _offersSub = scope.jobs.watchPendingOffers(uid).listen((offers) {
      if (!mounted) return;
      final live =
          offers.where((o) => !_closedOffers.contains(o.id)).toList();
      setState(() {
        _liveOffers = live;
        if (live.isEmpty) {
          _showOfferQueue = false;
        } else if (!jobBlocksIncomingOffers(_activeJob) && !_showOfferQueue) {
          _showOfferQueue = true;
          _tab = 0;
        }
      });
    });
    _fcm = scope.fcm;
    _fcmFocusListener = () {
      final id = scope.fcm.focusJobId.value;
      if (id == null || id.isEmpty || !mounted) return;
      final hasMatch = _liveOffers.any((o) => o.jobId == id);
      setState(() {
        _tab = 0;
        if (hasMatch && !jobBlocksIncomingOffers(_activeJob)) {
          _showOfferQueue = true;
        }
      });
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
    _startTracking();
    unawaited(scope.users.ensureProviderReady(widget.profile.id));
    unawaited(
      scope.jobs.redispatchWaitingJobs(
        providerRole: widget.profile.role.name,
      ),
    );
    if (mounted) setState(() {});
  }

  void _startTracking() {
    _posSub?.cancel();
    final scope = AppScope.of(context);
    _posSub = scope.location.track().listen((p) {
      final next = LatLng(p.latitude, p.longitude);
      _meNotifier.value = next;
      final geo = GeoPoint(p.latitude, p.longitude);
      if (!_geoThrottle.shouldWrite(geo)) return;
      scope.users.setGeo(widget.profile.id, geo);
    });
    final me = _meNotifier.value;
    final geo = GeoPoint(me.latitude, me.longitude);
    if (_geoThrottle.shouldWrite(geo, force: true)) {
      scope.users.setGeo(widget.profile.id, geo);
    }
  }

  void _stopTracking() {
    _posSub?.cancel();
    _posSub = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_fcmFocusListener != null) {
      _fcm?.focusJobId.removeListener(_fcmFocusListener!);
    }
    _stopTracking();
    _offersSub?.cancel();
    _activeJobSub?.cancel();
    _meNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FieldShell(
      tab: _tab,
      onTab: (i) => setState(() => _tab = i),
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
    _activeJobStream ??= AppScope.of(context)
        .jobs
        .watchActiveForTechnician(widget.profile.id);
    return IndexedStack(
      index: _tab,
      sizing: StackFit.expand,
      children: [
        _TechnicianMapTab(
          profileId: widget.profile.id,
          fallbackProfile: widget.profile,
          zone: _zone,
          meListenable: _meNotifier,
          userStream: userStream,
          activeJobStream: _activeJobStream!,
          liveOffers: _liveOffers,
          showOfferQueue: _showOfferQueue &&
              !jobBlocksIncomingOffers(_activeJob),
          onSoftDismissOffer: (id) => setState(() {
            _closedOffers.add(id);
            _liveOffers =
                _liveOffers.where((o) => o.id != id).toList(growable: false);
            if (_liveOffers.isEmpty) _showOfferQueue = false;
          }),
          onConsumedOffer: (id) => setState(() {
            _closedOffers.add(id);
            _liveOffers =
                _liveOffers.where((o) => o.id != id).toList(growable: false);
            if (_liveOffers.isEmpty) _showOfferQueue = false;
          }),
          onLocated: (point) => _meNotifier.value = point,
        ),
        _ordersTab(userStream, _ensureRecentJobs()),
        _walletTab(userStream),
        _accountTab(userStream),
      ],
    );
  }

  Widget _ordersTab(
    Stream<AppUser?> userStream,
    Stream<List<Job>> recentJobsStream,
  ) {
    return StreamBuilder<AppUser?>(
      stream: userStream,
      builder: (context, snap) {
        final me = snap.data ?? widget.profile;
        return Column(
          children: [
            if (_liveOffers.isNotEmpty &&
                !jobBlocksIncomingOffers(_activeJob))
              Material(
                color: const Color(0xFFFFF4D6),
                child: InkWell(
                  onTap: () => setState(() {
                    _showOfferQueue = true;
                    _tab = 0;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.notification_important_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _liveOffers.length == 1
                                ? 'طلب جديد بانتظار ردّك'
                                : '${_liveOffers.length} طلبات جديدة بانتظار ردّك',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.chevron_left),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: OrdersScreen(
                stream: recentJobsStream,
                profile: me,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _walletTab(Stream<AppUser?> userStream) {
    return StreamBuilder<AppUser?>(
      stream: userStream,
      builder: (context, snap) {
        final me = snap.data ?? widget.profile;
        return _WalletPage(
          me: me,
          city: _zone?.nameAr,
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
          city: _zone?.nameAr,
          isActive: _tab == 3,
          onOpenOrders: () => setState(() => _tab = 1),
          onOpenWallet: () => setState(() => _tab = 2),
        );
      },
    );
  }
}

class _TechnicianMapTab extends StatelessWidget {
  const _TechnicianMapTab({
    required this.profileId,
    required this.fallbackProfile,
    required this.zone,
    required this.meListenable,
    required this.userStream,
    required this.activeJobStream,
    required this.liveOffers,
    required this.showOfferQueue,
    required this.onSoftDismissOffer,
    required this.onConsumedOffer,
    required this.onLocated,
  });

  final String profileId;
  final AppUser fallbackProfile;
  final CityZone? zone;
  final ValueNotifier<LatLng> meListenable;
  final Stream<AppUser?> userStream;
  final Stream<Job?> activeJobStream;
  final List<JobOffer> liveOffers;
  final bool showOfferQueue;
  final ValueChanged<String> onSoftDismissOffer;
  final ValueChanged<String> onConsumedOffer;
  final ValueChanged<LatLng> onLocated;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: userStream,
      builder: (context, profileSnap) {
        final me = profileSnap.data ?? fallbackProfile;
        final ready = me.canReceiveJobs;
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
                                caption: 'الفني',
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StatusPill(
                                      label: ready
                                          ? 'جاهز للطلبات'
                                          : (me.isApproved
                                              ? 'رصيد غير كافٍ'
                                              : 'بانتظار التوثيق'),
                                      color: ready
                                          ? AppColors.emeraldDeep
                                          : AppColors.inkSoft,
                                      background: ready
                                          ? AppColors.emeraldTint
                                          : AppColors.recessed,
                                    ),
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
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: FieldCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          ready
                                              ? 'بانتظار طلبات الخدمة'
                                              : (me.isApproved
                                                  ? 'اشحن المحفظة لاستقبال الطلبات'
                                                  : AppStrings.pendingVerify),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'الرصيد ${formatIqd(me.walletBalance)}',
                                          style: const TextStyle(
                                            color: AppColors.inkSoft,
                                            fontSize: 12,
                                          ),
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
                    if (showOfferQueue &&
                        liveOffers.isNotEmpty &&
                        !jobBlocksIncomingOffers(job))
                      Positioned.fill(
                        child: OfferOverlay(
                          offers: liveOffers,
                          technicianName: me.name,
                          onSoftDismiss: onSoftDismissOffer,
                          onConsumed: onConsumedOffer,
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
