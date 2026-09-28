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
import 'package:barrr/features/customer/customer_account_page.dart';
import 'package:barrr/features/customer/parts_order_screen.dart';
import 'package:barrr/features/customer/technician_request_form.dart';
import 'package:barrr/features/customer/oil_request_form.dart';
import 'package:barrr/features/customer/tow_request_form.dart';
import 'package:barrr/features/customer/wash_request_form.dart';
import 'package:barrr/features/jobs/orders_screen.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranties_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/oil_type.dart';
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
  Stream<List<VehicleType>>? _vehicleTypesStream;
  Stream<List<OilType>>? _oilTypesStream;
  /// 0 = هبوط، 1 = خريطة الطلب — لتجديد الستريمات عند التبديل.
  var _homeSurface = 0;
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
        if (_tab != 0) _dropTabStreams();
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

  Stream<List<ServiceItem>> _ensureServices() {
    return _servicesStream ??= AppScope.of(context).users.watchServices();
  }

  Stream<List<Job>> _ensureRecentJobs() {
    return _recentJobsStream ??=
        AppScope.of(context).jobs.watchRecentForCustomer(widget.profile.id);
  }

  Stream<Job?> _ensureActiveJob() {
    return _activeJobStream ??=
        AppScope.of(context).jobs.watchActiveForCustomer(widget.profile.id);
  }

  /// الستريمات أحادية الاستماع: بعد تبديل التبويب نُنشئ ستريماً جديداً
  /// بدل إعادة الاستماع لنفس المثيل (خطأ Stream has already been listened to).
  void _dropTabStreams() {
    _activeJobStream = null;
    _recentJobsStream = null;
    _servicesStream = null;
    _vehicleTypesStream = null;
    _oilTypesStream = null;
  }

  void _dropCatalogStreams() {
    _servicesStream = null;
    _vehicleTypesStream = null;
    _oilTypesStream = null;
  }

  Stream<List<VehicleType>> _ensureVehicleTypes() {
    return _vehicleTypesStream ??=
        AppScope.of(context).users.watchVehicleTypes();
  }

  Stream<List<OilType>> _ensureOilTypes() {
    return _oilTypesStream ??= AppScope.of(context).users.watchOilTypes();
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
            _dropTabStreams();
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
        3 => CustomerAccountPage(
            profile: widget.profile,
            jobs: _ensureRecentJobs(),
            city: zoneName,
            onOpenOrders: () => _onTab(1),
            onOpenWallet: () => _onTab(2),
          ),
        _ => _homeTab(
            active: _ensureActiveJob(),
            recent: _ensureRecentJobs(),
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
        if (_tab != 0) _dropTabStreams();
        _tab = 0;
        _composing = false;
        _selected = null;
        _entryId = null;
        _vehicleType = null;
      });
      return;
    }
    setState(() {
      if (i != _tab) _dropTabStreams();
      _tab = i;
    });
  }

  /// تبويب الخريطة فقط يستمع للطلب النشط — لا يعيد بناء باقي التبويبات.
  Widget _homeTab({
    required Stream<Job?> active,
    required Stream<List<Job>> recent,
  }) {
    return StreamBuilder<Job?>(
      stream: active,
      builder: (context, snap) {
        final job = snap.data;
        final techForm = _composing && _entryId == 'technician';
        final oilForm = _composing && _entryId == 'oil';
        final towForm = _composing && _entryId == 'towing';
        final washForm = _composing && _entryId == 'wash';
        final dedicatedForm = techForm || oilForm || towForm || washForm;
        final showMap =
            (job != null && !job.isPartsOrder) || (_composing && !dedicatedForm);
        if (showMap && _homeSurface != 1) {
          _homeSurface = 1;
          _dropCatalogStreams();
        } else if (!showMap && _homeSurface != 0) {
          _homeSurface = 0;
          _dropCatalogStreams();
        }
        final catalog = _ensureServices();
        final vehicles = _ensureVehicleTypes();
        final oils = _ensureOilTypes();
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
            services: catalog,
            vehicles: vehicles,
          );
        }
        void clearCompose() => setState(() {
              _dropCatalogStreams();
              _composing = false;
              _selected = null;
              _entryId = null;
              _vehicleType = null;
            });
        if (techForm) {
          return TechnicianRequestForm(
            profile: widget.profile,
            zone: _zone,
            initialPin: _pin,
            addressLabel: _addressLabel,
            inZone: _pinInZone(),
            services: catalog,
            vehicleTypes: vehicles,
            onBack: clearCompose,
            onSubmitted: clearCompose,
          );
        }
        if (oilForm) {
          return OilRequestForm(
            profile: widget.profile,
            zone: _zone,
            initialPin: _pin,
            addressLabel: _addressLabel,
            inZone: _pinInZone(),
            services: catalog,
            vehicleTypes: vehicles,
            oilTypes: oils,
            onBack: clearCompose,
            onSubmitted: clearCompose,
          );
        }
        if (towForm) {
          return TowRequestForm(
            profile: widget.profile,
            zone: _zone,
            initialPin: _pin,
            addressLabel: _addressLabel,
            inZone: _pinInZone(),
            services: catalog,
            onBack: clearCompose,
            onSubmitted: clearCompose,
          );
        }
        if (washForm) {
          return WashRequestForm(
            profile: widget.profile,
            zone: _zone,
            initialPin: _pin,
            addressLabel: _addressLabel,
            inZone: _pinInZone(),
            services: catalog,
            onBack: clearCompose,
            onSubmitted: clearCompose,
          );
        }
        if (_composing) {
          return _mapBody(
            null,
            _zone,
            services: catalog,
            vehicles: vehicles,
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
                  onTap: () => _onTab(1),
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
                services: catalog,
                recentJobs: recent,
                onServiceTap: _onLandingService,
                onEmergencyTap: _onEmergency,
                onOpenWarranties: () {
                  Navigator.of(context).push(
                    softPageRoute<void>(
                      builder: (_) => WarrantiesScreen(
                        stream: AppScope.of(context)
                            .jobs
                            .watchRecentForCustomer(widget.profile.id),
                        profile: widget.profile,
                      ),
                    ),
                  );
                },
                onOpenAccount: () => _onTab(3),
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
        _onTab(1);
      }
      return;
    }
    setState(() {
      _dropCatalogStreams();
      _entryId = s.id;
      // للفني نفتح الشبكة المفلترة دون اختيار مسبق؛ لبقية البلاطات نثبت الخدمة.
      _selected = s.id == 'technician' ? null : s;
      _composing = true;
    });
  }

  Future<void> _onEmergency() async {
    // لا نستمع لنفس ستريم الـ StreamBuilder (أحادي الاستماع).
    List<ServiceItem> items;
    try {
      items = await AppScope.of(context).users.watchServices().first;
    } catch (_) {
      items = seedServices.where((e) => e.active).toList();
    }
    if (items.isEmpty) items = seedServices.where((e) => e.active).toList();
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
      _dropCatalogStreams();
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
}

