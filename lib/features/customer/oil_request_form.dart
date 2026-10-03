import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/geo.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/shared/osm_map.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/oil_type.dart';
import 'package:barrr/models/service_item.dart';
import 'package:barrr/models/vehicle_type.dart';

/// صفحة طلب تبديل زيت متنقل — أنواع المركبات والزيوت من الأدمن.
class OilRequestForm extends StatefulWidget {
  const OilRequestForm({
    super.key,
    required this.profile,
    required this.zone,
    required this.initialPin,
    required this.addressLabel,
    required this.inZone,
    required this.services,
    required this.vehicleTypes,
    required this.oilTypes,
    required this.onBack,
    required this.onSubmitted,
  });

  final AppUser profile;
  final CityZone? zone;
  final LatLng initialPin;
  final String addressLabel;
  final bool inZone;
  final Stream<List<ServiceItem>> services;
  final Stream<List<VehicleType>> vehicleTypes;
  final Stream<List<OilType>> oilTypes;
  final VoidCallback onBack;
  final VoidCallback onSubmitted;

  @override
  State<OilRequestForm> createState() => _OilRequestFormState();
}

class _OilRequestFormState extends State<OilRequestForm> {
  final _map = MapController();
  final _vehicle = TextEditingController();
  final _year = TextEditingController();
  final _landmark = TextEditingController();
  final _phone = TextEditingController();

  late LatLng _pin;
  late String _addressLabel;
  var _inZone = true;
  VehicleType? _vehicleType;
  OilType? _oil;
  var _cylinders = 4;
  var _liters = 4.5;
  var _includeFilter = true;
  var _submitting = false;
  var _seededVehicle = false;
  var _seededOil = false;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialPin;
    _addressLabel = widget.addressLabel;
    _inZone = widget.inZone;
    _phone.text = widget.profile.phone;
  }

  @override
  void dispose() {
    _vehicle.dispose();
    _year.dispose();
    _landmark.dispose();
    _phone.dispose();
    _map.dispose();
    super.dispose();
  }

  void _ensureVehicle(List<VehicleType> vehicles) {
    if (_seededVehicle) return;
    if (vehicles.isEmpty) return;
    _seededVehicle = true;
    final next = _vehicleType ?? vehicles.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _vehicleType != null) return;
      setState(() => _vehicleType = next);
    });
  }

  void _ensureOil(List<OilType> oils) {
    if (_seededOil) return;
    if (oils.isEmpty) return;
    _seededOil = true;
    final next = _oil ?? oils.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _oil != null) return;
      setState(() => _oil = next);
    });
  }

  void _syncSelectedOil(List<OilType> oils) {
    if (oils.isEmpty) return;
    final current = _oil;
    if (current != null && oils.any((o) => o.id == current.id)) return;
    final next = oils.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_oil != null && oils.any((o) => o.id == _oil!.id)) return;
      setState(() => _oil = next);
    });
  }

  void _setCylinders(int n) {
    setState(() {
      _cylinders = n;
      _liters = switch (n) {
        6 => 6.0,
        8 => 8.0,
        _ => 4.5,
      };
    });
  }

  bool _pointInZone(LatLng p) {
    final z = widget.zone;
    if (z == null) return true;
    return isWithinRadiusKm(
      pointLat: p.latitude,
      pointLng: p.longitude,
      centerLat: z.centerLat,
      centerLng: z.centerLng,
      radiusKm: z.radiusKm,
    );
  }

  String _labelFor(LatLng p) {
    final coords =
        '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
    final zoneName = widget.zone?.nameAr ?? '';
    if (zoneName.isEmpty) return coords;
    return '$zoneName ($coords)';
  }

  Future<void> _pickLocation() async {
    final picked = await pickAddressOnMap(
      context,
      initial: _pin,
      title: 'موقع تقديم خدمة الزيت',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pin = picked.latLng;
      _addressLabel =
          picked.label.isNotEmpty ? picked.label : _labelFor(picked.latLng);
      _inZone = _pointInZone(picked.latLng);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _map.move(_pin, 14);
      } catch (_) {}
    });
  }

  ServiceItem _resolveOilService(List<ServiceItem> raw) {
    for (final s in raw) {
      if (s.id == 'oil' && s.active) return s;
    }
    return seedServices.firstWhere(
      (s) => s.id == 'oil',
      orElse: () => const ServiceItem(
        id: 'oil',
        titleAr: 'خدمة الزيوت',
        category: 'صيانة',
        providerKind: ServiceProviderKind.mobile,
      ),
    );
  }

  Future<void> _submit(ServiceItem oilService) async {
    if (_submitting) return;
    final vehicleType = _vehicleType;
    if (vehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر نوع المركبة')),
      );
      return;
    }
    final oil = _oil;
    if (oil == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر نوع الزيت')),
      );
      return;
    }
    if (!_inZone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الموقع خارج نطاق التغطية')),
      );
      return;
    }
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم الاتصال')),
      );
      return;
    }

    final vehicleRaw = _vehicle.text.trim();
    var make = vehicleRaw;
    var model = '';
    final parts = vehicleRaw.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      make = parts.first;
      model = parts.sublist(1).join(' ');
    }

    final landmark = _landmark.text.trim();
    final note = [
      'زيت: ${oil.nameAr}',
      'سلندر: $_cylinders',
      'كمية متوقعة: ${_liters.toStringAsFixed(1)} لتر',
      'فلتر الزيت (السيفون): ${_includeFilter ? 'نعم' : 'لا'}',
      if (landmark.isNotEmpty) 'علامة دالة: $landmark',
    ].join('\n');

    setState(() => _submitting = true);
    try {
      final scope = AppScope.of(context);
      final geo = GeoPoint(_pin.latitude, _pin.longitude);
      final address =
          landmark.isEmpty ? _addressLabel : '$_addressLabel — $landmark';
      await scope.users.setAddressAndGeo(
        widget.profile.id,
        address: address,
        geo: geo,
      );
      final jobId = await scope.jobs.createJob(
        customerId: widget.profile.id,
        serviceId: oilService.id,
        serviceTitle: oilService.titleAr,
        vehicleTypeId: vehicleType.id,
        vehicleTypeTitle: vehicleType.nameAr,
        exact: geo,
        isEmergency: false,
        commissionRate: oilService.commissionRate,
        partName: oil.nameAr,
        partNote: note,
        carMake: make,
        carModel: model,
        carYear: _year.text.trim(),
        customerPhone: phone,
        providerKind: 'oilWorkshop',
        oilTypeId: oil.id,
        oilTypeName: oil.nameAr,
        cylinders: _cylinders,
        liters: _liters,
        includeOilFilter: _includeFilter,
        landmark: landmark,
      );
      var dispatchFailed = false;
      try {
        await scope.dispatch
            .dispatch(jobId)
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        dispatchFailed = true;
      }
      if (!mounted) return;
      if (dispatchFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.jobCreatedDispatchFailed),
          ),
        );
      }
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال الطلب: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final city = widget.zone?.nameAr ?? 'البصرة';
    return ColoredBox(
      color: const Color(0xFFF8F9FF),
      child: Column(
        children: [
          _TopBar(city: city, uid: widget.profile.id, onBack: widget.onBack),
          Expanded(
            child: StreamBuilder<List<ServiceItem>>(
              stream: widget.services,
              builder: (context, serviceSnap) {
                return StreamBuilder<List<VehicleType>>(
                  stream: widget.vehicleTypes,
                  builder: (context, vehicleSnap) {
                    return StreamBuilder<List<OilType>>(
                      stream: widget.oilTypes,
                      builder: (context, oilSnap) {
                    final rawServices = (serviceSnap.data == null ||
                            serviceSnap.data!.isEmpty)
                        ? seedServices
                        : serviceSnap.data!;
                    final oilService = _resolveOilService(rawServices);
                    final vehicles = (vehicleSnap.data == null ||
                            vehicleSnap.data!.isEmpty)
                        ? seedVehicleTypes
                        : vehicleSnap.data!;
                    final oils = oilSnap.data ?? const <OilType>[];
                    _ensureVehicle(vehicles);
                    _ensureOil(oils);
                    _syncSelectedOil(oils);
                    final selectedOil = _oil != null &&
                            oils.any((o) => o.id == _oil!.id)
                        ? _oil
                        : (oils.isNotEmpty ? oils.first : null);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _stepHeader(1, 'المركبة'),
                              const SizedBox(height: 10),
                              const _Label('نوع المركبة'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final t in vehicles)
                                    FilterChip(
                                      label: Text(
                                        t.nameAr,
                                        style: const TextStyle(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      selected: _vehicleType?.id == t.id,
                                      showCheckmark: true,
                                      checkmarkColor: AppColors.ink,
                                      backgroundColor: AppColors.recessed,
                                      selectedColor: AppColors.amber,
                                      onSelected: (_) =>
                                          setState(() => _vehicleType = t),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const _Label('الشركة والموديل'),
                                        const SizedBox(height: 6),
                                        _IconField(
                                          controller: _vehicle,
                                          icon: Icons.directions_car_outlined,
                                          hint: 'الموديل',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const _Label('سنة الصنع'),
                                        const SizedBox(height: 6),
                                        _IconField(
                                          controller: _year,
                                          icon: Icons.calendar_today_outlined,
                                          hint: '2022',
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const _Label('سعة المحرك'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (final n in const [4, 6, 8]) ...[
                                    if (n != 4) const SizedBox(width: 8),
                                    Expanded(
                                      child: _CylinderBtn(
                                        cylinders: n,
                                        litersHint: '',
                                        selected: _cylinders == n,
                                        onTap: () => _setCylinders(n),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _stepHeader(
                                2,
                                'الزيت',
                              ),
                              const SizedBox(height: 10),
                              const _Label('نوع الزيت'),
                              const SizedBox(height: 6),
                              if (oils.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.recessed,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'لا توجد أنواع زيوت',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.inkSoft,
                                      height: 1.35,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.recessed,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedOil?.id,
                                      isExpanded: true,
                                      icon: const Icon(Icons.expand_more),
                                      items: [
                                        for (final o in oils)
                                          DropdownMenuItem(
                                            value: o.id,
                                            child: Text(
                                              o.nameAr,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        if (v == null) return;
                                        final match = oils
                                            .where((o) => o.id == v)
                                            .firstOrNull;
                                        if (match == null) return;
                                        setState(() => _oil = match);
                                      },
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.recessed,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.filter_alt_outlined),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'فلتر الزيت',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: _includeFilter,
                                      activeThumbColor: AppColors.slate,
                                      onChanged: (v) =>
                                          setState(() => _includeFilter = v),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.recessed.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'اللترات',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    _QtyBtn(
                                      label: '−',
                                      onTap: () {
                                        if (_liters <= 2) return;
                                        setState(() => _liters -= 0.5);
                                      },
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        _liters.toStringAsFixed(1),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    _QtyBtn(
                                      label: '+',
                                      onTap: () {
                                        if (_liters >= 12) return;
                                        setState(() => _liters += 0.5);
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'لتر',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _stepHeader(3, 'الموقع'),
                                  ),
                                  TextButton.icon(
                                    onPressed: _pickLocation,
                                    icon: const Icon(Icons.edit_location_alt,
                                        size: 16),
                                    label: const Text('تعديل الدبوس'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.amberDeep,
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  height: 140,
                                  child: Stack(
                                    children: [
                                      OsmMap(
                                        mapController: _map,
                                        center: _pin,
                                        zoom: 14,
                                        showMyLocation: false,
                                        interactive: false,
                                        circles: [
                                          if (widget.zone != null)
                                            coverageCircle(
                                              centerLat: widget.zone!.centerLat,
                                              centerLng: widget.zone!.centerLng,
                                              radiusKm: widget.zone!.radiusKm,
                                            ),
                                        ],
                                      ),
                                      const IgnorePointer(
                                        child: Center(
                                          child: Icon(
                                            Icons.location_on,
                                            color: AppColors.amberDeep,
                                            size: 38,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                AppColors.slate
                                                    .withValues(alpha: 0.85),
                                              ],
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.location_on,
                                                  color: AppColors.amber,
                                                  size: 18),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  _inZone
                                                      ? _addressLabel
                                                      : 'خارج التغطية',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const _Label('علامة دالة'),
                              const SizedBox(height: 6),
                              _IconField(
                                controller: _landmark,
                                icon: Icons.pin_drop_outlined,
                                hint: 'علامة دالة',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _stepHeader(4, 'الهاتف'),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.recessed,
                                  prefixIcon: const Icon(Icons.call,
                                      color: AppColors.amberDeep),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: _submitting ||
                                    vehicles.isEmpty ||
                                    oils.isEmpty
                                ? null
                                : () => _submit(oilService),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.slate,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.oil_barrel,
                                          color: AppColors.amber),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'إرسال الطلب لأقرب فني زيوت',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _stepHeader(int step, String title, {String? trailing, String? badge}) {
  return Row(
    children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.slate,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$step',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (badge != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, size: 13, color: AppColors.amberDeep),
              const SizedBox(width: 3),
              Text(
                badge,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amberDeep,
                ),
              ),
            ],
          ),
        )
      else if (trailing != null)
        Text(
          trailing,
          style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
        ),
    ],
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.city,
    required this.uid,
    required this.onBack,
  });

  final String city;
  final String uid;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F9FF).withValues(alpha: 0.92),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                ),
                const FieldMark(size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.recessed,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              city,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                NotificationsBellButton(uid: uid),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CylinderBtn extends StatelessWidget {
  const _CylinderBtn({
    required this.cylinders,
    required this.litersHint,
    required this.selected,
    required this.onTap,
  });

  final int cylinders;
  final String litersHint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.slate : AppColors.recessed,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            children: [
              Text(
                '$cylinders سلندر',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
              if (litersHint.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  litersHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: selected ? Colors.white70 : AppColors.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.inkSoft,
      ),
    );
  }
}

class _IconField extends StatelessWidget {
  const _IconField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
        filled: true,
        fillColor: AppColors.recessed,
        prefixIcon: Icon(icon, size: 18, color: AppColors.inkSoft),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }
}
