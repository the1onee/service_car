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
import 'package:barrr/models/service_item.dart';
import 'package:barrr/models/vehicle_type.dart';

class WashPackage {
  const WashPackage({
    required this.id,
    required this.nameAr,
    required this.icon,
  });

  final String id;
  final String nameAr;
  final IconData icon;
}

const washPackages = <WashPackage>[
  WashPackage(
    id: 'exterior',
    nameAr: 'غسيل خارجي',
    icon: Icons.water_drop_outlined,
  ),
  WashPackage(
    id: 'interior',
    nameAr: 'غسيل داخلي',
    icon: Icons.airline_seat_recline_normal_outlined,
  ),
  WashPackage(
    id: 'full',
    nameAr: 'غسيل كامل',
    icon: Icons.local_car_wash_outlined,
  ),
  WashPackage(
    id: 'polish',
    nameAr: 'تلميع',
    icon: Icons.auto_awesome_outlined,
  ),
];

/// صفحة طلب غسيل سيارات متنقل — باقات وأنواع مركبات من الكتالوج.
class WashRequestForm extends StatefulWidget {
  const WashRequestForm({
    super.key,
    required this.profile,
    required this.zone,
    required this.initialPin,
    required this.addressLabel,
    required this.inZone,
    required this.services,
    required this.vehicleTypes,
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
  final VoidCallback onBack;
  final VoidCallback onSubmitted;

  @override
  State<WashRequestForm> createState() => _WashRequestFormState();
}

class _WashRequestFormState extends State<WashRequestForm> {
  final _map = MapController();
  final _vehicle = TextEditingController();
  final _year = TextEditingController();
  final _note = TextEditingController();
  final _landmark = TextEditingController();
  final _phone = TextEditingController();

  late LatLng _pin;
  late String _addressLabel;
  var _inZone = true;
  VehicleType? _vehicleType;
  WashPackage _package = washPackages[2];
  var _submitting = false;
  var _seededVehicle = false;

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
    _note.dispose();
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
      title: 'موقع غسيل السيارة',
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

  ServiceItem _resolveWashService(List<ServiceItem> raw) {
    for (final s in raw) {
      if (s.id == 'wash' && s.active) return s;
    }
    return seedServices.firstWhere(
      (s) => s.id == 'wash',
      orElse: () => const ServiceItem(
        id: 'wash',
        titleAr: 'غسيل السيارات',
        category: 'عناية',
        providerKind: ServiceProviderKind.mobile,
      ),
    );
  }

  Future<void> _submit(ServiceItem washService) async {
    if (_submitting) return;
    if (!_inZone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الموقع خارج نطاق التغطية')),
      );
      return;
    }
    final vehicleType = _vehicleType;
    if (vehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر نوع المركبة')),
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
    final note = _note.text.trim();

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
        serviceId: washService.id,
        serviceTitle: washService.titleAr,
        vehicleTypeId: vehicleType.id,
        vehicleTypeTitle: vehicleType.nameAr,
        exact: geo,
        isEmergency: false,
        commissionRate: washService.commissionRate,
        partName: _package.nameAr,
        partNote: note,
        carMake: make,
        carModel: model,
        carYear: _year.text.trim(),
        customerPhone: phone,
        providerKind: washService.providerKind.firestoreValue,
        landmark: landmark,
        washPackageId: _package.id,
        washPackageName: _package.nameAr,
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
                    final raw = (serviceSnap.data == null ||
                            serviceSnap.data!.isEmpty)
                        ? seedServices
                        : serviceSnap.data!;
                    final washService = _resolveWashService(raw);
                    final vehicles = (vehicleSnap.data == null ||
                            vehicleSnap.data!.isEmpty)
                        ? seedVehicleTypes
                        : vehicleSnap.data!;
                    _ensureVehicle(vehicles);

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
                                        const _Label('الشركة ونوع الشركة'),
                                        const SizedBox(height: 6),
                                        _IconField(
                                          controller: _vehicle,
                                          icon: Icons.directions_car_outlined,
                                          hint: 'تويوتا كامري',
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _stepHeader(2, 'باقة الغسيل'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final p in washPackages)
                                    FilterChip(
                                      avatar: Icon(
                                        p.icon,
                                        size: 18,
                                        color: _package.id == p.id
                                            ? AppColors.ink
                                            : AppColors.inkSoft,
                                      ),
                                      label: Text(
                                        p.nameAr,
                                        style: const TextStyle(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      selected: _package.id == p.id,
                                      showCheckmark: false,
                                      backgroundColor: AppColors.recessed,
                                      selectedColor: AppColors.amber,
                                      onSelected: (_) =>
                                          setState(() => _package = p),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const _Label('ملاحظة اختيارية'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _note,
                                maxLines: 3,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'مثلاً: التركيز على الداخلية…',
                                  hintStyle: const TextStyle(
                                    color: AppColors.inkSoft,
                                    fontSize: 12,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.recessed,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
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
                                  Expanded(child: _stepHeader(3, 'الموقع')),
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
                                hint: 'بجانب المسجد / بوابة المجمع…',
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
                            onPressed: _submitting || vehicles.isEmpty
                                ? null
                                : () => _submit(washService),
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
                                      Icon(Icons.local_car_wash,
                                          color: AppColors.amber),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'إرسال الطلب لأقرب فني غسيل',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepHeader(int step, String title) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.slate,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
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
                      const Text(
                        'طلب غسيل',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        city,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
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

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        fontSize: 12,
        fontWeight: FontWeight.w700,
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
      style: const TextStyle(fontSize: 14),
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
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
