import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/geo.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/customer/customer_ledger_page.dart';
import 'package:barrr/features/customer/job_status_panel.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/jobs/orders_screen.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranties_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/features/shared/osm_map.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/service_item.dart';
import 'package:barrr/models/vehicle_type.dart';
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
  var _tab = 0;
  ServiceItem? _selected;
  VehicleType? _vehicleType;

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

  Future<void> _confirmAndRequest() async {
    final service = _selected;
    final vehicle = _vehicleType;
    if (service == null) return;
    if (vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.selectVehicleTypeRequired)),
      );
      return;
    }
    // مزامنة الدبوس مع مركز الخريطة الفعلي قبل الإرسال.
    try {
      _pin = _map.camera.center;
    } catch (_) {}
    if (!_pinInZone()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.outsideCoverage)),
      );
      return;
    }
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
      vehicleTypeId: vehicle.id,
      vehicleTypeTitle: vehicle.nameAr,
      exact: geo,
      isEmergency: service.isEmergency,
      commissionRate: service.commissionRate,
    );
    await scope.dispatch.dispatch(jobId);
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
    setState(() => _pin = result.latLng);
    _map.move(result.latLng, _zoom);
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
            return FieldShell(
              tab: _tab,
              onTab: (i) => setState(() => _tab = i),
              items: const [
                FieldNavItem(
                    icon: Icons.home_repair_service_outlined,
                    label: 'الرئيسية'),
                FieldNavItem(icon: Icons.assignment_outlined, label: 'الطلبات'),
                FieldNavItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'المحفظة'),
                FieldNavItem(icon: Icons.person_outline_rounded, label: 'حسابي'),
              ],
              body: IndexedStack(
                index: _tab,
                children: [
                  _mapBody(job, zone),
                  OrdersScreen(
                    stream: scope.jobs
                        .watchRecentForCustomer(widget.profile.id),
                    profile: widget.profile,
                  ),
                  CustomerLedgerPage(
                    stream: scope.jobs
                        .watchRecentForCustomer(widget.profile.id),
                    profile: widget.profile,
                    city: zone?.nameAr,
                  ),
                  _account(zone?.nameAr),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _mapBody(Job? job, CityZone? zone) {
    final markers = <Marker>[
      if (job != null)
        pinMarker(
          LatLng(job.displayLocation.latitude, job.displayLocation.longitude),
          color: AppColors.amber,
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
    return Stack(
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
            onPositionChanged: job == null
                ? (c) => setState(() => _pin = c)
                : null,
          ),
        if (_ready && job == null)
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.location_on,
                    color: AppColors.amberDeep, size: 42),
              ),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: FieldTopBar(city: zone?.nameAr),
        ),
        if (_ready && job != null)
          Positioned(
            top: 108,
            left: 16,
            right: 16,
            child: Material(
              color: AppColors.surface,
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  AppStrings.locationLockedDuringJob,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        if (_ready && job == null)
          Positioned(
            top: 108,
            left: 16,
            child: _MapButton(icon: Icons.my_location, onTap: _recenter),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: job == null
              ? _RequestComposer(
                  zone: zone,
                  inZone: _pinInZone(),
                  selected: _selected,
                  vehicleType: _vehicleType,
                  onSelect: (s) {
                    setState(() => _selected = s);
                  },
                  onSelectVehicle: (t) {
                    setState(() => _vehicleType = t);
                  },
                  onPickLocation: _openMapPicker,
                  onSubmit: _confirmAndRequest)
              : CustomerJobPanel(job: job, me: widget.profile),
        ),
      ],
    );
  }

  Widget _account(String? city) {
    final me = widget.profile;
    final jobs = AppScope.of(context).jobs.watchRecentForCustomer(me.id);
    return Column(
      children: [
        FieldTopBar(city: city, caption: 'حسابي'),
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

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.slate.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
            width: 44, height: 44, child: Icon(icon, color: AppColors.ink)),
      ),
    );
  }
}

class _RequestComposer extends StatelessWidget {
  const _RequestComposer({
    required this.zone,
    required this.inZone,
    required this.selected,
    required this.vehicleType,
    required this.onSelect,
    required this.onSelectVehicle,
    required this.onPickLocation,
    required this.onSubmit,
  });

  final CityZone? zone;
  final bool inZone;
  final ServiceItem? selected;
  final VehicleType? vehicleType;
  final ValueChanged<ServiceItem> onSelect;
  final ValueChanged<VehicleType> onSelectVehicle;
  final VoidCallback onPickLocation;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final emergency = selected?.isEmergency ?? false;
    return Material(
      color: AppColors.surface,
      elevation: 16,
      shadowColor: AppColors.slate.withValues(alpha: 0.18),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.58),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: emergency ? AppColors.amberTint : AppColors.recessed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emergency
                              ? 'استجابة طوارئ الطريق'
                              : 'طلب خدمة ميدانية',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          zone == null
                              ? 'حرّك الخريطة أو حدد الموقع من الزر'
                              : 'تغطية ${zone!.nameAr}',
                          style: const TextStyle(
                              color: AppColors.inkSoft, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: emergency ? AppColors.amber : AppColors.slate,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      emergency ? Icons.bolt : Icons.build_outlined,
                      color: emergency ? AppColors.ink : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FieldCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.place_outlined, color: AppColors.inkSoft),
                title: const Text('موقع العطل',
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                subtitle: Text(
                  inZone
                      ? (zone?.nameAr ?? 'موقعك على الخريطة')
                      : AppStrings.outsideCoverage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: inZone ? AppColors.ink : AppColors.danger,
                    fontSize: 13,
                  ),
                ),
                trailing: TextButton(
                  onPressed: onPickLocation,
                  child: const Text(AppStrings.pickLocationOnMap),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const SectionLabel('حدد نوع الخدمة'),
            StreamBuilder<List<ServiceItem>>(
              stream: AppScope.of(context).users.watchServices(),
              builder: (context, snap) {
                final items = snap.data ?? const <ServiceItem>[];
                if (items.isEmpty) {
                  return const Text('لا توجد خدمات متاحة حالياً.');
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 88,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, i) {
                    final s = items[i];
                    final on = selected?.id == s.id;
                    return InkWell(
                      onTap: () => onSelect(s),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: on
                              ? (s.isEmergency
                                  ? AppColors.slate
                                  : AppColors.recessed)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: on
                                ? (s.isEmergency
                                    ? AppColors.slate
                                    : AppColors.amber)
                                : AppColors.outline,
                            width: on ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _serviceIcon(s.id),
                              size: 20,
                              color: on && s.isEmergency
                                  ? AppColors.amber
                                  : AppColors.ink,
                            ),
                            const Spacer(),
                            Text(
                              s.titleAr,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: on && s.isEmergency
                                    ? Colors.white
                                    : AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 14),
            const SectionLabel(AppStrings.pickVehicleType),
            StreamBuilder<List<VehicleType>>(
              stream: AppScope.of(context).users.watchVehicleTypes(),
              builder: (context, snap) {
                final items = snap.data ?? seedVehicleTypes;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in items)
                      FilterChip(
                        label: Text(t.nameAr),
                        selected: vehicleType?.id == t.id,
                        onSelected: (_) => onSelectVehicle(t),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'السعر يحدده الفني بعد الفحص، والدفع نقداً عند انتهاء العمل.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  selected == null || vehicleType == null ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: emergency ? AppColors.amber : AppColors.slate,
                foregroundColor: emergency ? AppColors.ink : Colors.white,
                disabledBackgroundColor: AppColors.outline,
              ),
              icon: Icon(emergency ? Icons.bolt : Icons.arrow_back),
              label: Text(emergency ? 'طلب فني طوارئ فوري' : 'اطلب الفني'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _serviceIcon(String id) {
  switch (id) {
    case 'battery':
      return Icons.battery_charging_full;
    case 'towing':
      return Icons.local_shipping_outlined;
    case 'tires':
      return Icons.album_outlined;
    case 'fuel':
      return Icons.local_gas_station_outlined;
    case 'locks':
      return Icons.key_outlined;
    case 'oil':
      return Icons.oil_barrel_outlined;
    case 'ac':
      return Icons.ac_unit;
    default:
      return Icons.build_outlined;
  }
}
