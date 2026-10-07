import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/cloudinary_config.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/service_item.dart';
import 'package:barrr/services/cloudinary_upload.dart';
import 'package:barrr/services/specialties_catalog.dart';

/// نتيجة إرسال طلب القطع — للانتقال لتبويب الطلبات.
class PartsOrderResult {
  const PartsOrderResult({required this.jobId, this.goOrders = true});

  final String jobId;
  final bool goOrders;
}

/// تصميم طلب تسعير قطع الغيار.
class PartsOrderScreen extends StatefulWidget {
  const PartsOrderScreen({
    super.key,
    required this.profile,
    required this.service,
  });

  final AppUser profile;
  final ServiceItem service;

  @override
  State<PartsOrderScreen> createState() => _PartsOrderScreenState();
}

class _PartsOrderScreenState extends State<PartsOrderScreen> {
  final _form = GlobalKey<FormState>();
  final _vehicle = TextEditingController();
  final _carYear = TextEditingController();
  final _partDetails = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _uploader = CloudinaryUpload();

  LatLng? _pin;
  String? _partImageUrl;
  String? _specialtyId;
  String _specialtyAr = '';
  List<SpecialtyOption> _specialties = const [];
  var _loadingSpecialties = true;
  String? _specialtiesError;
  var _submitting = false;
  var _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _phone.text = widget.profile.phone;
    _address.text = widget.profile.address;
    final geo = widget.profile.geo;
    if (geo != null) {
      _pin = LatLng(geo.latitude, geo.longitude);
    }
    _loadSpecialties();
  }

  Future<void> _loadSpecialties() async {
    setState(() {
      _loadingSpecialties = true;
      _specialtiesError = null;
    });
    try {
      final list = await loadWorkshopSpecialties(role: 'workshop');
      if (!mounted) return;
      setState(() {
        _specialties = list;
        _loadingSpecialties = false;
        _specialtiesError = list.isEmpty
            ? 'لا توجد اختصاصات'
            : null;
        if (_specialtyId != null &&
            !list.any((s) => s.id == _specialtyId)) {
          _specialtyId = null;
          _specialtyAr = '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _specialties = const [];
        _loadingSpecialties = false;
        _specialtiesError = 'تعذر تحميل الاختصاصات: $e';
      });
    }
  }

  @override
  void dispose() {
    _vehicle.dispose();
    _carYear.dispose();
    _partDetails.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final picked = await pickAddressOnMap(
      context,
      initial: _pin,
      title: 'موقع التوصيل على الخريطة',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pin = picked.latLng;
      if (picked.label.isNotEmpty) _address.text = picked.label;
    });
  }

  Future<void> _pickPartPhoto() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final url = await _uploader.pickAndUpload(
        folder: CloudinaryConfig.folderParts,
        tags: const ['parts_order'],
        imageQuality: 55,
        maxWidth: 1280,
      );
      if (!mounted) return;
      setState(() => _partImageUrl = url);
    } catch (e) {
      if (!mounted) return;
      if (!e.toString().contains('cancelled')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرفاق الصورة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final pin = _pin;
    if (pin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدّد موقع التوصيل على الخريطة.')),
      );
      return;
    }
    final specialtyId = _specialtyId;
    if (specialtyId == null || specialtyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر اختصاص سيارتك.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final scope = AppScope.of(context);
      final geo = GeoPoint(pin.latitude, pin.longitude);
      final address = _address.text.trim().isEmpty
          ? '${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)}'
          : _address.text.trim();
      await scope.users.setAddressAndGeo(
        widget.profile.id,
        address: address,
        geo: geo,
      );

      final vehicle = _vehicle.text.trim();
      final parts = vehicle.split(RegExp(r'\s+'));
      final make = parts.isEmpty ? vehicle : parts.first;
      final model =
          parts.length <= 1 ? '' : parts.sublist(1).join(' ');

      final jobId = await scope.jobs.createJob(
        customerId: widget.profile.id,
        serviceId: widget.service.id,
        serviceTitle: widget.service.titleAr,
        exact: geo,
        isEmergency: false,
        commissionRate: 0,
        partName: _partDetails.text.trim(),
        partNote: '',
        partImageUrl: _partImageUrl ?? '',
        carMake: make,
        carModel: model,
        carYear: _carYear.text.trim(),
        customerPhone: _phone.text.trim(),
        deliveryAddress: address,
        providerKind: 'workshop',
        specialtyId: specialtyId,
        specialtyAr: _specialtyAr,
      );
      // توزيع محلي مباشر لقطع الغيار مع إعادة محاولة — لا نعتمد على CF هنا.
      var dispatchFailed = false;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await scope.dispatch
              .dispatch(jobId)
              .timeout(const Duration(seconds: 25));
          // تأكد أن الطلب خرج من حالة التوزيع.
          final job = await scope.jobs.watchJob(jobId).first.timeout(
                const Duration(seconds: 5),
              );
          if (job != null &&
              (job.status == JobStatus.offerPending ||
                  job.status == JobStatus.noTechnician ||
                  job.status == JobStatus.comparing)) {
            dispatchFailed = false;
            break;
          }
          dispatchFailed = true;
        } catch (_) {
          dispatchFailed = true;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dispatchFailed
                ? AppStrings.jobCreatedDispatchFailed
                : 'تم الإرسال',
          ),
        ),
      );
      Navigator.of(context).pop(
        PartsOrderResult(jobId: jobId, goOrders: true),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال الطلب: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _fieldDeco({String? hint, Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF76777D), fontSize: 14),
      filled: true,
      fillColor: AppColors.petrolTint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.azureTint, width: 1.5),
      ),
      prefixIcon: prefix,
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final city = _cityHint();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          Material(
            color: AppColors.canvas.withValues(alpha: 0.88),
            elevation: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
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
                                if (city.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.azureTint,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      city,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF45464D),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      NotificationsBellButton(uid: widget.profile.id),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Form(
              key: _form,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.edit_note_rounded, color: AppColors.amberDeep, size: 22),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'الطلب',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          const _Label('اختصاص السيارة'),
                          if (_loadingSpecialties)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          else if (_specialties.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _specialtiesError ??
                                    'لا توجد اختصاصات مفعّلة حالياً.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB3261E),
                                ),
                              ),
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: _loadSpecialties,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ),
                          ] else
                            DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: _specialtyId,
                              decoration: _fieldDeco(hint: 'اختر الاختصاص'),
                              items: _specialties
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.nameAr),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                var name = '';
                                for (final s in _specialties) {
                                  if (s.id == v) {
                                    name = s.nameAr;
                                    break;
                                  }
                                }
                                setState(() {
                                  _specialtyId = v;
                                  _specialtyAr = name;
                                });
                              },
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'اختر الاختصاص.' : null,
                            ),
                          if (_specialtiesError != null &&
                              _specialties.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _specialtiesError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB3261E),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          const _Label('المركبة'),
                          TextFormField(
                            controller: _vehicle,
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDeco(
                              hint: 'مثال: هيونداي سنتافي، تويوتا كورولا',
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'أدخل الشركة ونوع الشركة.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          const _Label('سنة الصنع'),
                          TextFormField(
                            controller: _carYear,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDeco(hint: 'مثال: 2021'),
                          ),
                          const SizedBox(height: 12),
                          const _Label('القطعة'),
                          TextFormField(
                            controller: _partDetails,
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDeco(
                              hint: 'مثال: دينمو شحن، سفايف أمامية، كمبريسور',
                            ),
                            validator: (v) => (v ?? '').trim().length < 2
                                ? 'أدخل وصف القطعة.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          const _Label('الصورة'),
                          if (_partImageUrl != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 22,
                                    color: AppColors.emerald,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'تم رفع الصورة',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'إزالة',
                                    onPressed: () =>
                                        setState(() => _partImageUrl = null),
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            Material(
                              color: AppColors.petrolTint,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: _pickingImage ? null : _pickPartPhoto,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFC6C6CD),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_pickingImage)
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else ...[
                                        const Icon(
                                          Icons.photo_camera_outlined,
                                          size: 20,
                                          color: AppColors.amberDeep,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'صورة',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF45464D),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          const _Label('العنوان'),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _address,
                                  decoration: _fieldDeco(
                                    hint: 'العنوان',
                                    suffix: const Icon(
                                      Icons.location_on,
                                      color: AppColors.amberDeep,
                                      size: 20,
                                    ),
                                  ),
                                  validator: (v) => (v ?? '').trim().isEmpty
                                      ? 'أدخل عنوان التوصيل.'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 48,
                                child: FilledButton.tonal(
                                  onPressed: _pickAddress,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.azureTint,
                                    foregroundColor: AppColors.ink,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.map_outlined, size: 18),
                                      SizedBox(width: 4),
                                      Text(
                                        'الخريطة',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_pin != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'تم تثبيت الموقع على الخريطة',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          const _Label('الهاتف'),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            decoration: _fieldDeco(
                              hint: '0770 123 4567',
                              prefix: const Icon(
                                Icons.phone_iphone,
                                color: Color(0xFF009668),
                                size: 20,
                              ),
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                            validator: (v) => (v ?? '').trim().length < 8
                                ? 'أدخل رقم هاتف صالح.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: _submitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.black54,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.send_rounded, size: 22),
                                        SizedBox(width: 8),
                                        Text(
                                          'إرسال الطلب للورش المختصة',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cityHint() {
    final a = widget.profile.address;
    if (a.contains('بصرة')) return 'البصرة';
    if (a.isEmpty) return 'البصرة';
    return a.split(RegExp(r'[،,]')).first.trim();
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

