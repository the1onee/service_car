import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/cloudinary_config.dart';
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
import 'package:barrr/services/cloudinary_upload.dart';

/// صفحة طلب فني — الخدمات وأنواع المركبات من كتالوج الأدمن (Firestore).
class TechnicianRequestForm extends StatefulWidget {
  const TechnicianRequestForm({
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
  State<TechnicianRequestForm> createState() => _TechnicianRequestFormState();
}

class _TechnicianRequestFormState extends State<TechnicianRequestForm> {
  final _map = MapController();
  final _vehicle = TextEditingController();
  final _year = TextEditingController();
  final _note = TextEditingController();
  final _landmark = TextEditingController();
  final _phone = TextEditingController();
  final _uploader = CloudinaryUpload();

  late LatLng _pin;
  late String _addressLabel;
  var _inZone = true;
  ServiceItem? _selected;
  VehicleType? _vehicleType;
  String? _imageUrl;
  var _pickingImage = false;
  var _submitting = false;
  var _seededSelection = false;

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

  /// خدمات فني ميداني من الأدمن؛ نستبعد بلاطة الدخول العامة إن وُجدت خدمات أدق.
  List<ServiceItem> _techServices(List<ServiceItem> raw) {
    final filtered = filterServicesForEntry('technician', raw);
    final specific = filtered.where((s) => s.id != 'technician').toList();
    return specific.isNotEmpty ? specific : filtered;
  }

  void _ensureDefaults(List<ServiceItem> services, List<VehicleType> vehicles) {
    if (_seededSelection) return;
    if (services.isEmpty && vehicles.isEmpty) return;
    _seededSelection = true;
    final nextService = _selected ?? (services.isNotEmpty ? services.first : null);
    final nextVehicle =
        _vehicleType ?? (vehicles.isNotEmpty ? vehicles.first : null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selected ??= nextService;
        _vehicleType ??= nextVehicle;
      });
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
      title: 'تعديل موقع الطلب',
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

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final url = await _uploader.pickAndUpload(
        folder: CloudinaryConfig.folderParts,
        tags: const ['technician_request'],
      );
      if (!mounted) return;
      setState(() => _imageUrl = url);
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('cancelled')) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرفاق الصورة: $e')),
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final service = _selected;
    final vehicleType = _vehicleType;
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر نوع الخدمة أو العطل')),
      );
      return;
    }
    if (vehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر نوع المركبة')),
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
    final note = _note.text.trim();
    final combinedNote = [
      if (note.isNotEmpty) note,
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
        serviceId: service.id,
        serviceTitle: service.titleAr,
        vehicleTypeId: vehicleType.id,
        vehicleTypeTitle: vehicleType.nameAr,
        exact: geo,
        isEmergency: service.isEmergency,
        commissionRate: service.commissionRate,
        partNote: combinedNote,
        partImageUrl: _imageUrl ?? '',
        carMake: make,
        carModel: model,
        carYear: _year.text.trim(),
        customerPhone: phone,
        providerKind: service.providerKind.firestoreValue,
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
          _FormTopBar(
            city: city,
            uid: widget.profile.id,
            onBack: widget.onBack,
          ),
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
                    final services = _techServices(rawServices);
                    final vehicles = (vehicleSnap.data == null ||
                            vehicleSnap.data!.isEmpty)
                        ? seedVehicleTypes
                        : vehicleSnap.data!;
                    _ensureDefaults(services, vehicles);

                    if (serviceSnap.connectionState ==
                            ConnectionState.waiting &&
                        !serviceSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        _sectionTitle(1, 'نوع الخدمة'),
                        const SizedBox(height: 10),
                        if (services.isEmpty)
                          const _Card(
                            child: Text(
                              'لا توجد خدمات فني.',
                              style: TextStyle(color: AppColors.inkSoft),
                            ),
                          )
                        else
                          _CategoryGrid(
                            items: services,
                            selectedId: _selected?.id,
                            onSelect: (s) => setState(() => _selected = s),
                          ),
                        const SizedBox(height: 22),
                        _sectionTitle(2, 'بيانات المركبة'),
                        const SizedBox(height: 10),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _FieldLabel('نوع المركبة'),
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
                              const SizedBox(height: 14),
                              const _FieldLabel('الشركة المصنعة والموديل'),
                              const SizedBox(height: 6),
                              _IconField(
                                controller: _vehicle,
                                icon: Icons.directions_car_outlined,
                                hint: 'الموديل',
                              ),
                              const SizedBox(height: 12),
                              const _FieldLabel('سنة الصنع'),
                              const SizedBox(height: 6),
                              _IconField(
                                controller: _year,
                                icon: Icons.calendar_today_outlined,
                                hint: '2021',
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _sectionTitle(3, 'وصف العطل والصوت'),
                        const SizedBox(height: 10),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _note,
                                maxLines: 3,
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputDecoration(
                                  hint: 'وصف مختصر',
                                ),
                              ),
                              const SizedBox(height: 14),
                              const _FieldLabel('الصورة'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _AttachTile(
                                      icon: _imageUrl == null
                                          ? Icons.add_a_photo_outlined
                                          : Icons.check_circle,
                                      title: _imageUrl == null
                                          ? 'إرفاق صورة'
                                          : 'تم الرفع',
                                      subtitle: '',
                                      busy: _pickingImage,
                                      onTap: _pickImage,
                                      accent: _imageUrl != null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _AttachTile(
                                      icon: Icons.mic_none_rounded,
                                      title: 'تسجيل صوتي',
                                      subtitle: '',
                                      onTap: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'التسجيل الصوتي سيُفعَّل في تحديث قادم',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _sectionTitle(4, 'الموقع'),
                        const SizedBox(height: 10),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  height: 148,
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
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        child: Material(
                                          color: Colors.white
                                              .withValues(alpha: 0.95),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: InkWell(
                                            onTap: _pickLocation,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 7),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.tune,
                                                      size: 16,
                                                      color:
                                                          AppColors.amberDeep),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'تعديل الدبوس',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.recessed,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.pin_drop_outlined,
                                      color: _inZone
                                          ? AppColors.amberDeep
                                          : AppColors.danger,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _inZone
                                                ? (widget.zone?.nameAr ??
                                                    'موقع الطلب')
                                                : 'خارج التغطية',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: _inZone
                                                  ? AppColors.ink
                                                  : AppColors.danger,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _addressLabel,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.inkSoft,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _IconField(
                                controller: _landmark,
                                icon: Icons.storefront_outlined,
                                hint:
                                    'علامة دالة',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _sectionTitle(5, 'الهاتف'),
                        const SizedBox(height: 10),
                        _Card(
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: AppColors.recessed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.phone_in_talk_outlined,
                                    size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _phone,
                                      keyboardType: TextInputType.phone,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        letterSpacing: 0.3,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Text(
                                'تعديل',
                                style: TextStyle(
                                  color: AppColors.amberDeep,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: _submitting ||
                                    services.isEmpty ||
                                    vehicles.isEmpty
                                ? null
                                : _submit,
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
                                          'إرسال الطلب للفنيين القريبين',
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

Widget _sectionTitle(int step, String title,
    {String? trailing, Widget? trailingWidget}) {
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
            color: Color(0xFF7C839B),
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
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
      if (trailingWidget != null)
        trailingWidget
      else if (trailing != null)
        Text(
          trailing,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.amberDeep,
          ),
        ),
    ],
  );
}

InputDecoration _inputDecoration({required String hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
    filled: true,
    fillColor: AppColors.recessed,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

IconData _iconForService(String id) => switch (id) {
      'battery' => Icons.electric_bolt_rounded,
      'brakes' => Icons.build_rounded,
      'spark' => Icons.power_settings_new_rounded,
      'ac' => Icons.ac_unit_rounded,
      'tires' => Icons.album_outlined,
      'technician' => Icons.handyman_outlined,
      _ => Icons.build_circle_outlined,
    };

class _FormTopBar extends StatelessWidget {
  const _FormTopBar({
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
                  tooltip: 'رجوع',
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

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ServiceItem> items;
  final String? selectedId;
  final ValueChanged<ServiceItem> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 86,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, i) {
        final s = items[i];
        final on = selectedId == s.id;
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => onSelect(s),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: on ? AppColors.amber : AppColors.outline,
                  width: on ? 2 : 1,
                ),
                boxShadow: AppTheme.cardShadow(),
              ),
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: on ? AppColors.amber : AppColors.recessed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _iconForService(s.id),
                          size: 20,
                          color: on ? AppColors.ink : AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.titleAr,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (on)
                    const Positioned(
                      top: 0,
                      left: 0,
                      child: Icon(
                        Icons.check_circle,
                        size: 18,
                        color: AppColors.amberDeep,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
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
      style: const TextStyle(fontSize: 14),
      decoration: _inputDecoration(hint: hint).copyWith(
        prefixIcon: Icon(icon, size: 20, color: AppColors.inkSoft),
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool busy;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? AppColors.amberTint : AppColors.recessed,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent ? AppColors.amber : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, size: 20, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
