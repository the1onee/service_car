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

/// صفحة طلب سطحة ونقل مركبة — أنواع المركبات من كتالوج الإدارة.
class TowRequestForm extends StatefulWidget {
  const TowRequestForm({
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
  State<TowRequestForm> createState() => _TowRequestFormState();
}

class _TowRequestFormState extends State<TowRequestForm> {
  final _landmark = TextEditingController();
  final _note = TextEditingController();
  final _phone = TextEditingController();

  late LatLng _pickup;
  late String _pickupLabel;
  var _pickupInZone = true;

  LatLng? _dropoff;
  String _dropoffLabel = '';

  VehicleType? _vehicleType;
  var _seededVehicle = false;
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
    _note.dispose();
    _phone.dispose();
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
        isEmergency: false,
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
    final vehicleType = _vehicleType;
    if (vehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر نوع المركبة')),
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

    final landmark = _landmark.text.trim();
    final note = _note.text.trim();

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
        vehicleTypeId: vehicleType.id,
        vehicleTypeTitle: vehicleType.nameAr,
        exact: pickupGeo,
        isEmergency: false,
        commissionRate: towService.commissionRate,
        partName: 'سطحة',
        partNote: note,
        customerPhone: phone,
        providerKind: towService.providerKind.firestoreValue,
        landmark: landmark,
        pickupLabel: _pickupLabel,
        dropoff: dropoffGeo,
        dropoffLabel: _dropoffLabel,
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
                    final rawServices = (serviceSnap.data == null ||
                            serviceSnap.data!.isEmpty)
                        ? seedServices
                        : serviceSnap.data!;
                    final towService = _resolveTowService(rawServices);
                    final vehicles = (vehicleSnap.data == null ||
                            vehicleSnap.data!.isEmpty)
                        ? seedVehicleTypes
                        : vehicleSnap.data!;
                    _ensureVehicle(vehicles);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        _RouteCard(
                          pickup: _pickup,
                          pickupLabel:
                              _pickupInZone ? _pickupLabel : 'خارج التغطية',
                          landmark: _landmark,
                          dropoff: _dropoff,
                          dropoffLabel: _dropoffLabel,
                          hasDropoff: _dropoff != null,
                          onEditPickup: _pickPickup,
                          onPickDropoff: _pickDropoff,
                        ),
                        const SizedBox(height: 18),
                        _VehicleCard(
                          vehicles: vehicles,
                          selected: _vehicleType,
                          noteController: _note,
                          onSelect: (t) => setState(() => _vehicleType = t),
                        ),
                        const SizedBox(height: 18),
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
                            onPressed: _submitting || vehicles.isEmpty
                                ? null
                                : () => _submit(towService),
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

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.pickup,
    required this.pickupLabel,
    required this.landmark,
    required this.dropoff,
    required this.dropoffLabel,
    required this.hasDropoff,
    required this.onEditPickup,
    required this.onPickDropoff,
  });

  final LatLng pickup;
  final String pickupLabel;
  final TextEditingController landmark;
  final LatLng? dropoff;
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
                  'المسار',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RoutePreviewMap(pickup: pickup, dropoff: dropoff),
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
                    title: 'التحميل',
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
                            hintText: 'علامة دالة',
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
                    title: 'التنزيل',
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

class _RoutePreviewMap extends StatelessWidget {
  const _RoutePreviewMap({required this.pickup, required this.dropoff});

  final LatLng pickup;
  final LatLng? dropoff;

  @override
  Widget build(BuildContext context) {
    final to = dropoff;
    final center = to == null
        ? pickup
        : LatLng(
            (pickup.latitude + to.latitude) / 2,
            (pickup.longitude + to.longitude) / 2,
          );
    double zoom = 14;
    if (to != null) {
      final dLat = (pickup.latitude - to.latitude).abs();
      final dLng = (pickup.longitude - to.longitude).abs();
      final span = dLat > dLng ? dLat : dLng;
      if (span < 0.005) {
        zoom = 15;
      } else if (span < 0.02) {
        zoom = 13;
      } else if (span < 0.05) {
        zoom = 12;
      } else if (span < 0.1) {
        zoom = 11;
      } else {
        zoom = 10;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 170,
        child: Stack(
          children: [
            OsmMap(
              key: ValueKey(
                '${pickup.latitude},${pickup.longitude},'
                '${to?.latitude},${to?.longitude}',
              ),
              center: center,
              zoom: zoom,
              showMyLocation: false,
              interactive: true,
              markers: [
                Marker(
                  point: pickup,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.trip_origin,
                    color: AppColors.amberDeep,
                    size: 32,
                  ),
                ),
                if (to != null)
                  Marker(
                    point: to,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.flag,
                      color: AppColors.slate,
                      size: 32,
                    ),
                  ),
              ],
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Row(
                children: [
                  _LegendChip(color: AppColors.amberDeep, label: 'تحميل'),
                  const SizedBox(width: 6),
                  _LegendChip(color: AppColors.slate, label: 'تنزيل'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
    required this.vehicles,
    required this.selected,
    required this.noteController,
    required this.onSelect,
  });

  final List<VehicleType> vehicles;
  final VehicleType? selected;
  final TextEditingController noteController;
  final ValueChanged<VehicleType> onSelect;

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
                'نوع المركبة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  selected: selected?.id == t.id,
                  showCheckmark: true,
                  checkmarkColor: AppColors.ink,
                  backgroundColor: AppColors.recessed,
                  selectedColor: AppColors.amber,
                  onSelected: (_) => onSelect(t),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ملاحظة اختيارية',
              hintStyle:
                  const TextStyle(color: AppColors.inkSoft, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFFEFF4FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
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
                  'الهاتف',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onToggleEdit,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.amberDeep,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(editing ? 'تم' : 'تعديل'),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
