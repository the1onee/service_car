import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/geo.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/customer/customer_landing.dart';
import 'package:barrr/features/customer/customer_request_map.dart';
import 'package:barrr/features/customer/customer_ledger_page.dart';
import 'package:barrr/features/customer/parts_order_screen.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/jobs/orders_screen.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranties_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/service_item.dart';
import 'package:barrr/models/vehicle_type.dart';
import 'package:barrr/services/fcm_service.dart';
import 'package:barrr/services/location_service.dart';

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
  var _gpsStarted = false;
  var _tab = 0;
  var _submitting = false;
  var _composing = false;
  ServiceItem? _selected;
  /// نقطة الدخول من الهبوط (`technician` / `oil` / …) لتصفية شبكة الخدمات.
  String? _entryId;
  VehicleType? _vehicleType;
  StreamSubscription<CityZone?>? _citySub;
  Stream<Job?>? _activeJobStream;
  Stream<List<Job>>? _recentJobsStream;
  Stream<List<ServiceItem>>? _servicesStream;
  var _deferredStarted = false;
  late final Stream<List<ServiceItem>> _seedServicesStream = Stream.value(
    seedServices.where((e) => e.active).toList(),
  );
  late final Stream<List<Job>> _emptyJobsStream = Stream.value(const []);
  Stream<List<VehicleType>>? _vehicleTypesStream;
  VoidCallback? _fcmFocusListener;
  FcmService? _fcm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    if (_locStarted) return;
    _locStarted = true;
    _fcm = scope.fcm;
    _fcmFocusListener = () {
      final id = scope.fcm.focusJobId.value;
      if (id == null || id.isEmpty || !mounted) return;
      setState(() {
        if (_tab != 0) _dropJobStreams();
        _tab = 0;
        _composing = false;
        _selected = null;
        _entryId = null;
        _vehicleType = null;
      });
      scope.fcm.focusJobId.value = null;
    };
    scope.fcm.focusJobId.addListener(_fcmFocusListener!);
    _fcmFocusListener!();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDeferred());
  }

  void _startDeferred() {
    if (!mounted || _deferredStarted) return;
    _deferredStarted = true;
    final scope = AppScope.of(context);
    _citySub = scope.settings.watchActiveCity().listen((zone) {
      if (!mounted) return;
      if (zone?.nameAr == _zone?.nameAr &&
          zone?.centerLat == _zone?.centerLat) {
        return;
      }
      setState(() => _zone = zone);
    });
    setState(() {
      _servicesStream ??= scope.users.watchServices();
      _recentJobsStream ??=
          scope.jobs.watchRecentForCustomer(widget.profile.id);
    });
    _initLocation();
  }

  Stream<List<ServiceItem>> get _landingServices =>
      _servicesStream ?? _seedServicesStream;

  Stream<List<Job>> get _landingRecent => _recentJobsStream ?? _emptyJobsStream;

  Stream<List<Job>> _ensureRecentJobs() {
    return _recentJobsStream ??=
        AppScope.of(context).jobs.watchRecentForCustomer(widget.profile.id);
  }

  /// البث أحادي الاستماع؛ بعد إغلاق التبويب لا يُعاد استخدامه.
  void _dropJobStreams() {
    _activeJobStream = null;
    _recentJobsStream = null;
  }

  Stream<List<VehicleType>> _ensureVehicleTypes() {
    return _vehicleTypesStream ??=
        AppScope.of(context).users.watchVehicleTypes();
  }

  @override
  void dispose() {
    if (_fcmFocusListener != null) {
      _fcm?.focusJobId.removeListener(_fcmFocusListener!);
    }
    _citySub?.cancel();
    _timeoutWatch?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final scope = AppScope.of(context);
    try {
      final settings = await scope.settings.getSettings();
      final zone = await scope.settings.getActiveCity();
      final saved = widget.profile.geo;
      final fallback = saved != null
          ? LatLng(saved.latitude, saved.longitude)
          : zone != null
              ? LatLng(zone.centerLat, zone.centerLng)
              : const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
      if (!mounted) return;
      setState(() {
        _zone = zone;
        _zoom = settings.defaultZoom;
        _pin = fallback;
        _ready = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _map.move(fallback, settings.defaultZoom);
        } catch (_) {}
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _ready = true);
    }
  }

  /// الموقع الحي عند فتح الخريطة فقط، لا على صفحة الهبوط.
  void _ensureGps() {
    if (_gpsStarted || !_ready) return;
    _gpsStarted = true;
    final fallback = _pin;
    final zoom = _zoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshGps(fallback, zoom);
    });
  }

  Future<void> _refreshGps(LatLng fallback, double zoom) async {
    try {
      final loc = await AppScope.of(context)
          .location
          .currentOrDefault(fallback: fallback);
      if (!mounted) return;
      if (loc.latitude == _pin.latitude && loc.longitude == _pin.longitude) {
        return;
      }
      setState(() => _pin = loc);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _map.move(loc, zoom);
        } catch (_) {}
      });
    } catch (_) {}
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

  String get _addressLabel {
    final coords =
        '${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)}';
    final zoneName = _zone?.nameAr ?? '';
    if (zoneName.isEmpty) return coords;
    return '$zoneName ($coords)';
  }

  Future<void> _confirmAndRequest() async {
    if (_submitting) return;
    final service = _selected;
    final vehicle = _vehicleType;
    if (service == null) return;
    if (vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.selectVehicleTypeRequired)),
      );
      return;
    }
    try {
      _pin = _map.camera.center;
    } catch (_) {}
    if (!_pinInZone()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.outsideCoverage)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final scope = AppScope.of(context);
      final geo = GeoPoint(_pin.latitude, _pin.longitude);
      await scope.users.setAddressAndGeo(
        widget.profile.id,
        address: _addressLabel,
        geo: geo,
      );
      final jobId = await scope.jobs.createJob(
        customerId: widget.profile.id,
        serviceId: service.id,
        serviceTitle: service.titleAr,
        vehicleTypeId: vehicle.id,
        vehicleTypeTitle: vehicle.nameAr,
        exact: geo,
        isEmergency: service.isEmergency,
        commissionRate: service.commissionRate,
      );
      // توزيع بمهلة قصيرة حتى لا تُبتلع الأخطاء وتبقى الواجهة معلّقة.
      try {
        await scope.dispatch
            .dispatch(jobId)
            .timeout(const Duration(seconds: 12));
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _composing = false;
        _selected = null;
        _entryId = null;
        _vehicleType = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال الطلب: $e')),
      );
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _watchTimeout(Job? job, BuildContext context) {
    _timeoutWatch?.cancel();
    if (job == null ||
        job.status != JobStatus.offerPending ||
        job.expiresAt == null) {
      return;
    }
    final wait =
        job.expiresAt!.difference(DateTime.now()) + const Duration(seconds: 2);
    if (wait.isNegative) {
      AppScope.of(context).dispatch.onWindowExpired(job.id);
      return;
    }
    _timeoutWatch = Timer(wait, () {
      AppScope.of(context).dispatch.onWindowExpired(job.id);
    });
  }

  Future<void> _openMapPicker() async {
    final picked = await pickAddressOnMap(
      context,
      initial: _pin,
      title: AppStrings.pickLocationOnMap,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pin = picked.latLng;
      if (picked.zone != null) _zone = picked.zone;
    });
    _map.move(picked.latLng, _zoom);
  }

  void _selectMapPoint(LatLng point) {
    _pin = point;
    _map.move(point, _zoom);
    setState(() {});
  }

  Future<void> _recenter() async {
    final scope = AppScope.of(context);
    final result = await scope.location.currentWithStatus(fallback: _pin);
    if (!mounted) return;
    if (result.outcome != LocationOutcome.ok) {
      final forever = result.outcome == LocationOutcome.deniedForever;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            forever
                ? AppStrings.locationPermissionDeniedForever
                : AppStrings.locationPermissionDenied,
          ),
          action: forever
              ? SnackBarAction(
                  label: AppStrings.openSettings,
                  onPressed: () => scope.location.openAppSettings(),
                )
              : null,
        ),
      );
    }
    _pin = result.latLng;
    _map.move(result.latLng, _zoom);
    setState(() {});
  }

  void _syncPinFromMap(LatLng center) {
    // يُستدعى فقط عند انتهاء السحب (OsmMap يتجاهل hasGesture=true).
    if (_pin.latitude == center.latitude &&
        _pin.longitude == center.longitude) {
      return;
    }
    _pin = center;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_tab == 0) {
      _activeJobStream ??=
          AppScope.of(context).jobs.watchActiveForCustomer(widget.profile.id);
    }
    final active = _activeJobStream;
    if (_tab == 0 && active == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final zoneName = _zone?.nameAr;
    final stayInApp = _composing || _tab != 0;
    return PopScope(
      canPop: !stayInApp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_composing) {
          setState(() {
            _composing = false;
            _selected = null;
            _entryId = null;
            _vehicleType = null;
          });
          return;
        }
        if (_tab != 0) {
          setState(() {
            _dropJobStreams();
            _tab = 0;
          });
        }
      },
      child: FieldShell(
      tab: _tab,
      onTab: _onTab,
      items: const [
        FieldNavItem(
            icon: Icons.home_repair_service_outlined, label: 'الرئيسية'),
        FieldNavItem(icon: Icons.assignment_outlined, label: 'الطلبات'),
        FieldNavItem(
            icon: Icons.account_balance_wallet_outlined, label: 'المحفظة'),
        FieldNavItem(icon: Icons.person_outline_rounded, label: 'حسابي'),
      ],
      // switch بدل IndexedStack حتى لا تبقى StreamBuilders للتبويبات المخفية نشطة.
      body: switch (_tab) {
        1 => OrdersScreen(
            stream: _ensureRecentJobs(),
            profile: widget.profile,
          ),
        2 => CustomerLedgerPage(
            stream: _ensureRecentJobs(),
            profile: widget.profile,
            city: zoneName,
          ),
        3 => _account(zoneName, _ensureRecentJobs()),
        _ => _homeTab(
            active: active!,
            recent: _landingRecent,
            services: _landingServices,
          ),
      },
    ),
    );
  }

  void _onTab(int i) {
    if (i == 0) {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
      setState(() {
        if (_tab != 0) _dropJobStreams();
        _tab = 0;
        _composing = false;
        _selected = null;
        _entryId = null;
        _vehicleType = null;
      });
      return;
    }
    setState(() {
      if (i != _tab) _dropJobStreams();
      _tab = i;
    });
  }

  /// تبويب الخريطة فقط يستمع للطلب النشط — لا يعيد بناء باقي التبويبات.
  Widget _homeTab({
    required Stream<Job?> active,
    required Stream<List<Job>> recent,
    required Stream<List<ServiceItem>> services,
  }) {
    return StreamBuilder<Job?>(
      stream: active,
      builder: (context, snap) {
        final job = snap.data;
        // طلبات القطع بلا نافذة زمنية؛ لا تُحبَس الواجهة على لوحة الطلب.
        if (job != null && !job.isPartsOrder) {
          _watchTimeout(job, context);
          if (_composing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _composing) {
                setState(() => _composing = false);
              }
            });
          }
          return _mapBody(
            job,
            _zone,
            services: services,
            vehicles: _ensureVehicleTypes(),
          );
        }
        if (_composing) {
          return _mapBody(
            null,
            _zone,
            services: services,
            vehicles: _ensureVehicleTypes(),
            showBack: true,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (job != null && job.isPartsOrder)
              Material(
                color: AppColors.azureTint,
                child: InkWell(
                  onTap: () => setState(() => _tab = 1),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.local_offer_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            job.partName.isNotEmpty
                                ? 'طلب قطع قيد العروض: ${job.partName}'
                                : 'لديك طلب قطع قيد العروض — تابع من الطلبات',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_left, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: CustomerLanding(
                profile: widget.profile,
                city: _zone?.nameAr,
                addressLabel: _addressLabel,
                services: services,
                recentJobs: recent,
                onServiceTap: _onLandingService,
                onEmergencyTap: () => _onEmergency(services),
                onOpenWarranties: () {
                  Navigator.of(context).push(
                    softPageRoute<void>(
                      builder: (_) => WarrantiesScreen(
                        stream: recent,
                        profile: widget.profile,
                      ),
                    ),
                  );
                },
                onOpenAccount: () => setState(() => _tab = 3),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onLandingService(ServiceItem s) async {
    if (s.id == 'parts') {
      final result = await Navigator.of(context).push<PartsOrderResult>(
        softPageRoute(
          builder: (_) => PartsOrderScreen(
            profile: widget.profile,
            service: s,
          ),
        ),
      );
      if (!mounted) return;
      if (result?.goOrders == true) {
        setState(() => _tab = 1);
      }
      return;
    }
    setState(() {
      _entryId = s.id;
      // للفني نفتح الشبكة المفلترة دون اختيار مسبق؛ لبقية البلاطات نثبت الخدمة.
      _selected = s.id == 'technician' ? null : s;
      _composing = true;
    });
  }

  Future<void> _onEmergency(Stream<List<ServiceItem>> servicesStream) async {
    final list = await servicesStream.first;
    final items = list.isEmpty ? seedServices : list;
    ServiceItem? emergency;
    for (final s in items) {
      if (s.isEmergency || s.id == 'towing') {
        emergency = s;
        if (s.id == 'towing') break;
      }
    }
    emergency ??= items.firstWhere(
      (s) => s.id == 'towing',
      orElse: () => seedServices.firstWhere((s) => s.id == 'towing'),
    );
    if (!mounted) return;
    setState(() {
      _entryId = emergency!.id;
      _selected = emergency;
      _composing = true;
    });
  }

  Widget _mapBody(
    Job? job,
    CityZone? zone, {
    required Stream<List<ServiceItem>> services,
    required Stream<List<VehicleType>> vehicles,
    bool showBack = false,
  }) {
    return CustomerRequestMap(
      profile: widget.profile,
      job: job,
      zone: zone,
      ready: _ready,
      mapController: _map,
      pin: _pin,
      zoom: _zoom,
      showBack: showBack,
      inZone: _pinInZone(),
      addressLabel: _addressLabel,
      selected: _selected,
      entryId: _entryId,
      vehicleType: _vehicleType,
      services: services,
      vehicleTypes: vehicles,
      busy: _submitting,
      onBack: () => setState(() {
        _composing = false;
        _selected = null;
        _entryId = null;
      }),
      onSelect: (s) => setState(() => _selected = s),
      onSelectVehicle: (t) => setState(() => _vehicleType = t),
      onPickLocation: _openMapPicker,
      onSubmit: _confirmAndRequest,
      onMapTap: job == null ? _selectMapPoint : null,
      onPositionChanged: job == null ? _syncPinFromMap : null,
      onLocated: (point) {
        _pin = point;
        setState(() {});
      },
      onRecenter: _recenter,
      onShown: _ensureGps,
    );
  }

  Widget _account(String? city, Stream<List<Job>> jobs) {
    final me = widget.profile;
    return Column(
      children: [
        FieldTopBar(
          city: city,
          caption: 'حسابي',
          trailing: NotificationsBellButton(uid: me.id),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              AccountHeader(
                name: me.name,
                subtitle: me.phone,
                trailing: const StatusPill(
                    label: 'عميل',
                    color: AppColors.ink,
                    background: AppColors.recessed),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Job>>(
                stream: jobs,
                builder: (context, snap) {
                  final rows = snap.data ?? const <Job>[];
                  final done = rows.where(jobIsDone).length;
                  final covered =
                      rows.where((j) => j.warranty.enabled).length;
                  return Row(
                    children: [
                      Expanded(child: _MiniStat(title: 'طلبات مكتملة', value: '$done')),
                      const SizedBox(width: 8),
                      Expanded(child: _MiniStat(title: 'وثائق ضمان', value: '$covered')),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const SectionLabel('الحساب'),
              FieldCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('سجل الضمانات'),
                      subtitle: const Text('المطالبات والتغطية السارية'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WarrantiesScreen(
                              stream: jobs,
                              profile: me,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: const Text('الطلبات'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => setState(() => _tab = 1),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: const Text('المدفوعات النقدية'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => setState(() => _tab = 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FieldCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('العنوان',
                        style:
                            TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(me.address.trim().isEmpty
                        ? 'يُحدَّد من الخريطة عند الطلب'
                        : me.address),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => signOutFrom(context),
                icon: const Icon(Icons.logout, color: AppColors.danger),
                label: const Text('تسجيل الخروج',
                    style: TextStyle(color: AppColors.danger)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return FieldCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
        ],
      ),
    );
  }
}

