import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/customer/parts_offers_section.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/service_item.dart';
import 'package:barrr/services/wallet_top_up_upload.dart';

/// تصميم طلب تسعير قطع الغيار + عروض الورش (مطابق للواجهة المرسلة).
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
  final _uploader = WalletTopUpUpload();

  LatLng? _pin;
  String? _partImageUrl;
  String? _jobId;
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
      final url = await _uploader.pickAndEncode();
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
        providerKind: 'workshop',
      );
      await scope.dispatch.dispatch(jobId);
      if (!mounted) return;
      setState(() => _jobId = jobId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الطلب. ستظهر عروض الورش أدناه.'),
        ),
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
                                const Text(
                                  'طلب الفني',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                if (city.isNotEmpty) ...[
                                  const SizedBox(width: 6),
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
                            const Text(
                              'قطع الغيار',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF45464D),
                              ),
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
                  Container(
                    width: double.infinity,
                    color: AppColors.petrolTint,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.amber,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.storefront, size: 16, color: AppColors.ink),
                                  SizedBox(width: 4),
                                  Text(
                                    'ورش ومحلات البصرة',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const Row(
                              children: [
                                _PulseDot(),
                                SizedBox(width: 6),
                                Text(
                                  'ورش نشطة الآن',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF45464D),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'طلب تسعير قطع الغيار',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'اكتب تفاصيل قطعتك واستلم عروض الأسعار والتوصيل فوراً من وكلاء ومحلات البصرة.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: Color(0xFF45464D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
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
                                      'بيانات الطلب',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'طلب سريع ومباشر',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF45464D),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              const _Label('نوع وصانع المركبة والموديل'),
                              TextFormField(
                                controller: _vehicle,
                                textInputAction: TextInputAction.next,
                                decoration: _fieldDeco(
                                  hint: 'مثال: هيونداي سنتافي، تويوتا كورولا',
                                ),
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? 'أدخل نوع وموديل المركبة.'
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
                              const _Label('اسم القطعة المطلوبة ووصفها البسيط'),
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
                              const _Label('إرفاق صورة للقطعة (اختياري)'),
                              if (_partImageUrl != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: _PartImage(dataUrl: _partImageUrl!),
                                  ),
                                ),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TextButton(
                                    onPressed: () =>
                                        setState(() => _partImageUrl = null),
                                    child: const Text('إزالة الصورة'),
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
                                          style: BorderStyle.solid,
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
                                              'التقاط صورة للقطعة أو رفعها من المعرض',
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
                              const _Label('العنوان وموقع التوصيل بالبصرة'),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _address,
                                      decoration: _fieldDeco(
                                        hint: 'مثال: البصرة، العشار، قرب جسر كنعان',
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
                              const _Label('رقم هاتف التواصل'),
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
                                  onPressed: _submitting || _jobId != null
                                      ? null
                                      : _submit,
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
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.send_rounded, size: 22),
                                            const SizedBox(width: 8),
                                            Text(
                                              _jobId == null
                                                  ? 'إرسال الطلب لورش البصرة'
                                                  : 'تم إرسال الطلب',
                                              style: const TextStyle(
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
                        if (_jobId != null) ...[
                          const SizedBox(height: 24),
                          StreamBuilder<Job?>(
                            stream: AppScope.of(context).jobs.watchJob(_jobId!),
                            builder: (context, snap) {
                              final job = snap.data;
                              if (job == null) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return PartsOffersSection(
                                job: job,
                                onAccepted: () {
                                  if (!mounted) return;
                                  Navigator.of(context).pop(true);
                                },
                              );
                            },
                          ),
                        ],
                      ],
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

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF009668),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PartImage extends StatelessWidget {
  const _PartImage({required this.dataUrl});

  final String dataUrl;

  @override
  Widget build(BuildContext context) {
    try {
      final comma = dataUrl.indexOf(',');
      final b64 = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
      return Image.memory(base64Decode(b64), fit: BoxFit.cover);
    } catch (_) {
      return const ColoredBox(
        color: Color(0xFFEFF4FF),
        child: Center(child: Text('تعذر عرض الصورة')),
      );
    }
  }
}
