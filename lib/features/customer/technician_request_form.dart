import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/app_snackbar.dart';
import 'package:barrr/core/cloudinary_config.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart' show AppColors;
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/features/customer/customer_request_shared.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
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

  bool _pointInZone(LatLng p) => requestPointInZone(p, widget.zone);

  String _labelFor(LatLng p) => requestAddressLabel(p, widget.zone);

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
      AppSnackBar.showError(context, 'تعذر إرفاق الصورة: $e');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final service = _selected;
    final vehicleType = _vehicleType;
    if (service == null) {
      AppSnackBar.showError(context, 'اختر نوع الخدمة أو العطل');
      return;
    }
    if (vehicleType == null) {
      AppSnackBar.showError(context, 'اختر نوع المركبة');
      return;
    }
    if (!_inZone) {
      AppSnackBar.showError(context, 'الموقع خارج نطاق التغطية');
      return;
    }
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      AppSnackBar.showError(context, 'أدخل رقم الاتصال');
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
        AppSnackBar.showInfo(context, AppStrings.jobCreatedDispatchFailed);
      }
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'تعذر إرسال الطلب: $e');
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
          RequestFormTopBar(
            title: 'طلب فني',
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
                        requestStepHeader(1, 'نوع الخدمة'),
                        const SizedBox(height: 10),
                        RequestFormCard(
                          child: services.isEmpty
                              ? const Text(
                                  'لا توجد خدمات مفعّلة لطلب فني. فعّل الخيار من لوحة الأدمن.',
                                  style: TextStyle(color: AppColors.inkSoft),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const RequestFormLabel('اختر نوع الخدمة'),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      // ignore: deprecated_member_use
                                      value: services.any(
                                              (s) => s.id == _selected?.id)
                                          ? _selected!.id
                                          : null,
                                      isExpanded: true,
                                      decoration: requestInputDecoration(
                                        hint: 'نوع الخدمة',
                                      ),
                                      hint: const Text('اختر نوع الخدمة'),
                                      items: [
                                        for (final s in services)
                                          DropdownMenuItem<String>(
                                            value: s.id,
                                            child: Text(
                                              s.titleAr,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: (id) {
                                        if (id == null) return;
                                        for (final s in services) {
                                          if (s.id == id) {
                                            setState(() => _selected = s);
                                            return;
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 22),
                        requestStepHeader(2, 'بيانات المركبة'),
                        const SizedBox(height: 10),
                        RequestFormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const RequestFormLabel('نوع المركبة'),
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
                              const RequestFormLabel('الشركة المصنعة ونوع الشركة'),
                              const SizedBox(height: 6),
                              RequestIconField(
                                controller: _vehicle,
                                icon: Icons.directions_car_outlined,
                                hint: 'نوع الشركة',
                              ),
                              const SizedBox(height: 12),
                              const RequestFormLabel('سنة الصنع'),
                              const SizedBox(height: 6),
                              RequestIconField(
                                controller: _year,
                                icon: Icons.calendar_today_outlined,
                                hint: '2021',
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        requestStepHeader(3, 'وصف العطل والصوت'),
                        const SizedBox(height: 10),
                        RequestFormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _note,
                                maxLines: 3,
                                style: const TextStyle(fontSize: 14),
                                decoration: requestInputDecoration(
                                  hint: 'وصف مختصر',
                                ),
                              ),
                              const SizedBox(height: 14),
                              const RequestFormLabel('الصورة'),
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
                        RequestLocationMapCard(
                          mapController: _map,
                          pin: _pin,
                          zone: widget.zone,
                          inZone: _inZone,
                          addressLabel: _addressLabel,
                          onEditPin: _pickLocation,
                          step: 4,
                          footer: RequestIconField(
                            controller: _landmark,
                            icon: Icons.storefront_outlined,
                            hint: 'علامة دالة',
                          ),
                        ),
                        const SizedBox(height: 22),
                        requestStepHeader(5, 'الهاتف'),
                        const SizedBox(height: 10),
                        RequestFormCard(
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
                        RequestSubmitButton(
                          submitting: _submitting,
                          enabled:
                              services.isNotEmpty && vehicles.isNotEmpty,
                          label: 'إرسال الطلب للفنيين القريبين',
                          icon: Icons.bolt,
                          onPressed: _submit,
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
