import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/geo.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/service_item.dart';

class _TowVehicleKind {
  const _TowVehicleKind({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

/// أنواع هيكل ثابتة لطلب السطحة (بدون كهربائية وبدون كتالوج الأدمن).
const _towVehicleKinds = <_TowVehicleKind>[
  _TowVehicleKind(
    id: 'sedan',
    label: 'صالون',
    icon: Icons.directions_car,
  ),
  _TowVehicleKind(
    id: 'suv',
    label: 'جيب / SUV',
    icon: Icons.directions_car_filled,
  ),
  _TowVehicleKind(
    id: 'pickup',
    label: 'بيك آب',
    icon: Icons.airport_shuttle,
  ),
  _TowVehicleKind(
    id: 'other',
    label: 'أخرى',
    icon: Icons.rv_hookup,
  ),
];

/// صفحة طلب سطحة ونقل مركبة.
class TowRequestForm extends StatefulWidget {
  const TowRequestForm({
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
  State<TowRequestForm> createState() => _TowRequestFormState();
}

class _TowRequestFormState extends State<TowRequestForm> {
  final _landmark = TextEditingController();
  final _vehicleName = TextEditingController();
  final _phone = TextEditingController();

  late LatLng _pickup;
  late String _pickupLabel;
  var _pickupInZone = true;

  LatLng? _dropoff;
  String _dropoffLabel = '';

  var _vehicleKind = _towVehicleKinds.first;
  var _phoneEditing = false;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _pickup = widget.initialPin;
    _pickupLabel = widget.addressLabel;
    _pickupInZone = widget.inZone;
    _phone.text = widget.profile.phone;
  }

  @override
  void dispose() {
    _landmark.dispose();
    _vehicleName.dispose();
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

  Future<void> _pickPickup() async {
    final picked = await pickAddressOnMap(
      context,
      initial: _pickup,
      title: 'مكان التحميل',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pickup = picked.latLng;
      _pickupLabel =
          picked.label.isNotEmpty ? picked.label : _labelFor(picked.latLng);
      _pickupInZone = _pointInZone(picked.latLng);
    });
  }

  Future<void> _pickDropoff() async {
    final picked = await pickAddressOnMap(
      context,
      initial: _dropoff ?? _pickup,
      title: 'مكان التنزيل (الوجهة)',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dropoff = picked.latLng;
      _dropoffLabel =
          picked.label.isNotEmpty ? picked.label : _labelFor(picked.latLng);
    });
  }

  ServiceItem _resolveTowService(List<ServiceItem> raw) {
    for (final s in raw) {
      if (s.id == 'towing' && s.active) return s;
    }
    return seedServices.firstWhere(
      (s) => s.id == 'towing',
      orElse: () => const ServiceItem(
        id: 'towing',
        titleAr: 'سطحة ومساعدة على الطريق',
        category: 'طوارئ',
        providerKind: ServiceProviderKind.mobile,
        isEmergency: true,
      ),
    );
  }

  Future<void> _submit(ServiceItem towService) async {
    if (_submitting) return;
    if (!_pickupInZone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مكان التحميل خارج نطاق التغطية')),
      );
      return;
    }
    final dropoff = _dropoff;
    if (dropoff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد مكان التنزيل على الخريطة')),
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

    final landmark = _landmark.text.trim();
    final note = [
      'طلب سطحة',
      'نوع الهيكل: ${_vehicleKind.label}',
      'تحميل: $_pickupLabel',
      if (landmark.isNotEmpty) 'علامة دالة: $landmark',
      'تنزيل: $_dropoffLabel',
      'إحداثيات التنزيل: ${dropoff.latitude.toStringAsFixed(5)}, ${dropoff.longitude.toStringAsFixed(5)}',
    ].join('\n');

    setState(() => _submitting = true);
    try {
      final scope = AppScope.of(context);
      final pickupGeo = GeoPoint(_pickup.latitude, _pickup.longitude);
      final dropoffGeo = GeoPoint(dropoff.latitude, dropoff.longitude);
      final address =
          landmark.isEmpty ? _pickupLabel : '$_pickupLabel — $landmark';
      await scope.users.setAddressAndGeo(
        widget.profile.id,
        address: address,
        geo: pickupGeo,
      );
      final jobId = await scope.jobs.createJob(
        customerId: widget.profile.id,
        serviceId: towService.id,
        serviceTitle: towService.titleAr,
        vehicleTypeId: _vehicleKind.id,
        vehicleTypeTitle: _vehicleKind.label,
        exact: pickupGeo,
        isEmergency: true,
        commissionRate: towService.commissionRate,
        partName: 'سطحة',
        partNote: note,
        carMake: make,
        carModel: model,
        customerPhone: phone,
        providerKind: towService.providerKind.firestoreValue,
        dropoff: dropoffGeo,
        dropoffLabel: _dropoffLabel,
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
                final rawServices = (serviceSnap.data == null ||
                        serviceSnap.data!.isEmpty)
                    ? seedServices
                    : serviceSnap.data!;
                final towService = _resolveTowService(rawServices);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _BannerCard(city: city),
                    const SizedBox(height: 12),
                    _RouteCard(
                      pickupLabel:
                          _pickupInZone ? _pickupLabel : 'خارج التغطية',
                      landmark: _landmark,
                      dropoffLabel: _dropoffLabel,
                      hasDropoff: _dropoff != null,
                      onEditPickup: _pickPickup,
                      onPickDropoff: _pickDropoff,
                    ),
                    const SizedBox(height: 12),
                    _VehicleCard(
                      selectedId: _vehicleKind.id,
                      nameController: _vehicleName,
                      onSelect: (k) => setState(() => _vehicleKind = k),
                    ),
                    const SizedBox(height: 12),
                    _PhoneCard(
                      controller: _phone,
                      editing: _phoneEditing,
                      onToggleEdit: () =>
                          setState(() => _phoneEditing = !_phoneEditing),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed:
                            _submitting ? null : () => _submit(towService),
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
                                  Icon(Icons.bolt, color: AppColors.amber),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'إرسال الطلب لأقرب سطحة متاحة',
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
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppColors.inkSoft),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'سيصلك إشعار فوري بعروض أسعار السطحات القريبة',
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
                        'طلب سطحة',
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
        color: AppColors.recessed,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -18,
            bottom: -22,
            child: Container(
              width: 96,
              height: 96,
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
                  color: AppColors.slate,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'طلب سطحة ونقل مركبة',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.amber,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, size: 13, color: AppColors.ink),
                              SizedBox(width: 2),
                              Text(
                                '24/7 سريعة',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'سطحات معتمدة ومجهزة لنقل آمن لجميع المركبات داخل وخارج $city',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.inkSoft,
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

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.pickupLabel,
    required this.landmark,
    required this.dropoffLabel,
    required this.hasDropoff,
    required this.onEditPickup,
    required this.onPickDropoff,
  });

  final String pickupLabel;
  final TextEditingController landmark;
  final String dropoffLabel;
  final bool hasDropoff;
  final VoidCallback onEditPickup;
  final VoidCallback onPickDropoff;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route, size: 20, color: AppColors.amberDeep),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'مسار النقل (من وإلى)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.recessed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'تحديد تلقائي دقيق',
                  style: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Stack(
            children: [
              Positioned(
                right: 13,
                top: 28,
                bottom: 28,
                child: Container(
                  width: 2,
                  color: const Color(0xFFD3E4FE),
                ),
              ),
              Column(
                children: [
                  _RouteStop(
                    icon: Icons.car_crash,
                    iconBg: AppColors.amber,
                    iconFg: AppColors.ink,
                    title: 'مكان التحميل (موقع المركبة الحالي)',
                    trailing: TextButton.icon(
                      onPressed: onEditPickup,
                      icon: const Icon(Icons.edit_location_alt, size: 14),
                      label: const Text('تعديل بالخريطة'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.amberDeep,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.my_location,
                                size: 16, color: AppColors.amberDeep),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                pickupLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: landmark,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText:
                                'علامة دالة (مثال: الشارع الرئيسي، أمام محطة وقود)',
                            hintStyle: const TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RouteStop(
                    icon: Icons.flag_circle,
                    iconBg: AppColors.slate,
                    iconFg: Colors.white,
                    title: 'مكان التنزيل (الوجهة)',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasDropoff) ...[
                          Row(
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 16, color: AppColors.amberDeep),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  dropoffLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.inkSoft,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: onPickDropoff,
                            icon: Icon(
                              hasDropoff
                                  ? Icons.edit_location_alt
                                  : Icons.pin_drop,
                              color: hasDropoff
                                  ? Colors.white
                                  : AppColors.amberDeep,
                            ),
                            label: Text(
                              hasDropoff
                                  ? 'تعديل الوجهة على الخريطة'
                                  : 'تحديد على الخارطة',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: hasDropoff
                                    ? Colors.white
                                    : AppColors.ink,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: hasDropoff
                                  ? AppColors.slate
                                  : Colors.white,
                              side: BorderSide(
                                color: hasDropoff
                                    ? AppColors.slate
                                    : const Color(0xFFC6C6CD),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
            boxShadow: AppTheme.softShadow(opacity: 0.12),
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Icon(icon, size: 14, color: iconFg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.selectedId,
    required this.nameController,
    required this.onSelect,
  });

  final String selectedId;
  final TextEditingController nameController;
  final ValueChanged<_TowVehicleKind> onSelect;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_car, size: 20, color: AppColors.amberDeep),
              SizedBox(width: 6),
              Text(
                'نوع السيارة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < _towVehicleKinds.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _VehicleKindTile(
                    kind: _towVehicleKinds[i],
                    selected: selectedId == _towVehicleKinds[i].id,
                    onTap: () => onSelect(_towVehicleKinds[i]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'حدد فئة أو اسم السيارة (مثال: كورولا، لاندكروزر...)',
              hintStyle:
                  const TextStyle(color: AppColors.inkSoft, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFFEFF4FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleKindTile extends StatelessWidget {
  const _VehicleKindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final _TowVehicleKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.slate : const Color(0xFFEFF4FF),
      borderRadius: BorderRadius.circular(12),
      elevation: selected ? 2 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.slate : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  kind.icon,
                  size: 22,
                  color: selected ? AppColors.amber : AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kind.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_in_talk,
                  size: 20, color: AppColors.amberDeep),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'رقم الهاتف',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onToggleEdit,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.amberDeep,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(editing ? 'تم' : 'تعديل الرقم'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.recessed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call,
                      size: 18, color: AppColors.amberDeep),
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
                      : Text(
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
                ),
                if (!editing)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'الرقم المعتمد',
                      style: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
