import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/geo.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/shared/osm_map.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/service_item.dart';

class _WashVehicleKind {
  const _WashVehicleKind({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

const _washVehicleKinds = <_WashVehicleKind>[
  _WashVehicleKind(
    id: 'sedan',
    label: 'صالون',
    icon: Icons.directions_car,
  ),
  _WashVehicleKind(
    id: 'suv',
    label: 'جيب / SUV',
    icon: Icons.directions_car_filled,
  ),
  _WashVehicleKind(
    id: 'van',
    label: 'فان / باص',
    icon: Icons.airport_shuttle,
  ),
  _WashVehicleKind(
    id: 'other',
    label: 'أخرى',
    icon: Icons.more_horiz,
  ),
];

/// صفحة طلب غسيل سيارات متنقل.
class WashRequestForm extends StatefulWidget {
  const WashRequestForm({
    super.key,
    required this.profile,
    required this.zone,
    required this.initialPin,
    required this.addressLabel,
    required this.inZone,
    required this.services,
    required this.onBack,
    required this.onSubmitted,
  });

  final AppUser profile;
  final CityZone? zone;
  final LatLng initialPin;
  final String addressLabel;
  final bool inZone;
  final Stream<List<ServiceItem>> services;
  final VoidCallback onBack;
  final VoidCallback onSubmitted;

  @override
  State<WashRequestForm> createState() => _WashRequestFormState();
}

class _WashRequestFormState extends State<WashRequestForm> {
  final _map = MapController();
  final _vehicleName = TextEditingController();
  final _otherKind = TextEditingController();
  final _landmark = TextEditingController();
  final _phone = TextEditingController();

  late LatLng _pin;
  late String _addressLabel;
  var _inZone = true;

  var _vehicleKind = _washVehicleKinds.first;
  var _phoneEditing = false;
  var _submitting = false;

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
    _map.dispose();
    _vehicleName.dispose();
    _otherKind.dispose();
    _landmark.dispose();
    _phone.dispose();
    super.dispose();
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
    if (_vehicleKind.id == 'other' && _otherKind.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب نوع أو فئة المركبة')),
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

    final vehicleRaw = _vehicleName.text.trim();
    var make = vehicleRaw;
    var model = '';
    final parts = vehicleRaw.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      make = parts.first;
      model = parts.sublist(1).join(' ');
    }

    final kindLabel = _vehicleKind.id == 'other'
        ? _otherKind.text.trim()
        : _vehicleKind.label;
    final landmark = _landmark.text.trim();
    final note = [
      'طلب غسيل متنقل',
      'نوع الهيكل: $kindLabel',
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
        serviceId: washService.id,
        serviceTitle: washService.titleAr,
        vehicleTypeId: _vehicleKind.id,
        vehicleTypeTitle: kindLabel,
        exact: geo,
        isEmergency: false,
        commissionRate: washService.commissionRate,
        partName: 'غسيل',
        partNote: note,
        carMake: make,
        carModel: model,
        customerPhone: phone,
        providerKind: washService.providerKind.firestoreValue,
      );
      try {
        await scope.dispatch
            .dispatch(jobId)
            .timeout(const Duration(seconds: 12));
      } catch (_) {}
      if (!mounted) return;
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
                final raw = (serviceSnap.data == null ||
                        serviceSnap.data!.isEmpty)
                    ? seedServices
                    : serviceSnap.data!;
                final washService = _resolveWashService(raw);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _BannerCard(city: city),
                    const SizedBox(height: 16),
                    _SectionHeader(
                      icon: Icons.directions_car,
                      title: 'نوع المركبة',
                      step: 'خطوة 1 من 3',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 0; i < _washVehicleKinds.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _VehicleTile(
                              kind: _washVehicleKinds[i],
                              selected:
                                  _vehicleKind.id == _washVehicleKinds[i].id,
                              onTap: () => setState(
                                () => _vehicleKind = _washVehicleKinds[i],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_vehicleKind.id == 'other') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _otherKind,
                        style: const TextStyle(fontSize: 14),
                        decoration: _fieldDecoration(
                          hint: 'اكتب نوع أو فئة المركبة هنا...',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: _vehicleName,
                      style: const TextStyle(fontSize: 14),
                      decoration: _fieldDecoration(
                        hint:
                            'موديل أو نوع السيارة (مثال: كيا سبورتاج، كامري 2022)',
                        icon: Icons.commute,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      icon: Icons.location_on,
                      title: 'موقع غسيل السيارة',
                      step: 'خطوة 2 من 3',
                    ),
                    const SizedBox(height: 10),
                    _LocationCard(
                      map: _map,
                      pin: _pin,
                      zone: widget.zone,
                      addressLabel: _inZone ? _addressLabel : 'خارج التغطية',
                      city: city,
                      landmark: _landmark,
                      onEdit: _pickLocation,
                    ),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      icon: Icons.call,
                      title: 'رقم الهاتف للتنسيق',
                      step: 'خطوة 3 من 3',
                    ),
                    const SizedBox(height: 10),
                    _PhoneCard(
                      controller: _phone,
                      editing: _phoneEditing,
                      onToggleEdit: () =>
                          setState(() => _phoneEditing = !_phoneEditing),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed:
                            _submitting ? null : () => _submit(washService),
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
                                  SizedBox(width: 8),
                                  Icon(Icons.bolt, color: AppColors.amber),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 16, color: AppColors.amberDeep),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'الدفع كاش بعد إتمام الغسيل • يصلك إشعار فوري بأقرب فني متاح',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 20, color: AppColors.inkSoft),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                      Row(
                        children: [
                          const Text(
                            'طلب الفني',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(width: 6),
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
                      const Text(
                        'غسيل متنقل',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.inkSoft),
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

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.city});

  final String city;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow(opacity: 0.18),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            bottom: -24,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_car_wash,
                    color: AppColors.amber, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'غسيل سيارات متنقل',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle,
                                  size: 7, color: AppColors.amber),
                              SizedBox(width: 4),
                              Text(
                                'خدمة ميدانية عند بابك',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFDDB8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'فنيو غسيل وتلميع متنقلون مع معدات ضغط ومواد معتمدة تصلك أينما كنت في $city.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.step,
  });

  final IconData icon;
  final String title;
  final String step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.amberDeep),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          step,
          style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final _WashVehicleKind kind;
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Icon(
                kind.icon,
                size: 22,
                color: selected ? Colors.white : AppColors.ink,
              ),
              const SizedBox(height: 6),
              Text(
                kind.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.map,
    required this.pin,
    required this.zone,
    required this.addressLabel,
    required this.city,
    required this.landmark,
    required this.onEdit,
  });

  final MapController map;
  final LatLng pin;
  final CityZone? zone;
  final String addressLabel;
  final String city;
  final TextEditingController landmark;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.near_me,
                      size: 18, color: AppColors.amberDeep),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$city — تحديد تلقائي',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        addressLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.recessed,
                    foregroundColor: AppColors.ink,
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('تعديل',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 96,
              child: Stack(
                children: [
                  OsmMap(
                    mapController: map,
                    center: pin,
                    zoom: 14,
                    showMyLocation: false,
                    interactive: false,
                    circles: [
                      if (zone != null)
                        coverageCircle(
                          centerLat: zone!.centerLat,
                          centerLng: zone!.centerLng,
                          radiusKm: zone!.radiusKm,
                        ),
                    ],
                  ),
                  const IgnorePointer(
                    child: Center(
                      child: Icon(
                        Icons.location_on,
                        color: AppColors.amberDeep,
                        size: 32,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.my_location,
                              size: 14, color: AppColors.amberDeep),
                          SizedBox(width: 4),
                          Text(
                            'نطاق وصول الفنيين: 10–25 دقيقة',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
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
          TextField(
            controller: landmark,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'علامة دالة (مثال: كراج البيت، مقابل مدرسة الفراهيدي)',
              hintStyle:
                  const TextStyle(color: AppColors.inkSoft, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFFEFF4FF),
              prefixIcon: const Icon(Icons.signpost_outlined,
                  size: 18, color: AppColors.inkSoft),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({
    required this.controller,
    required this.editing,
    required this.onToggleEdit,
  });

  final TextEditingController controller;
  final bool editing;
  final VoidCallback onToggleEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.recessed,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_iphone, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: editing
                ? TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.4,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.text.isEmpty
                            ? 'أدخل رقم الاتصال'
                            : controller.text,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: AppColors.emeraldDeep),
                          SizedBox(width: 4),
                          Text(
                            'الرقم المعتمد بحسابك',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.emeraldDeep,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          TextButton(
            onPressed: onToggleEdit,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.recessed,
              foregroundColor: AppColors.ink,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              editing ? 'تم' : 'تغيير',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
