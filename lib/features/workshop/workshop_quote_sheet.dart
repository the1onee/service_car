import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';

/// شاشة تقديم عرض سعر من الورشة لطلب قطع غيار.
class WorkshopQuoteSheet extends StatefulWidget {
  const WorkshopQuoteSheet({
    super.key,
    required this.offer,
    required this.workshopName,
    required this.onDone,
  });

  final JobOffer offer;
  final String workshopName;
  final VoidCallback onDone;

  @override
  State<WorkshopQuoteSheet> createState() => _WorkshopQuoteSheetState();
}

enum _PartCondition { oem, aftermarket, used }
enum _DeliveryType { delivery, pickup }

class _WorkshopQuoteSheetState extends State<WorkshopQuoteSheet> {

  final _price = TextEditingController();
  final _warrantyDays = TextEditingController(text: '30');
  final _warrantyNote = TextEditingController();
  final _vendorNotes = TextEditingController();

  _PartCondition _condition = _PartCondition.oem;
  _DeliveryType _delivery = _DeliveryType.delivery;
  late int _left;
  Timer? _timer;
  var _busy = false;
  String? _error;
  var _showImage = false;

  @override
  void initState() {
    super.initState();
    _left = widget.offer.remainingSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = widget.offer.remainingSeconds();
      if (n <= 0) {
        _timer?.cancel();
        widget.onDone();
      }
      if (mounted) setState(() => _left = n);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _price.dispose();
    _warrantyDays.dispose();
    _warrantyNote.dispose();
    _vendorNotes.dispose();
    super.dispose();
  }

  String get _conditionLabel => switch (_condition) {
        _PartCondition.oem => 'أصلي وكالة جديد',
        _PartCondition.aftermarket => 'كوري درجة أولى مضمون',
        _PartCondition.used => 'مستعمل تفصيخ مفحوص',
      };

  Future<void> _submit() async {
    final parsed = double.tryParse(_price.text.replaceAll(',', '').trim());
    final amountError = AppConstants.serviceAmountError(parsed);
    if (amountError != null || parsed == null) {
      setState(() => _error =
          amountError ?? 'أدخل مبلغاً ينتهي بـ 000، والحد الأدنى 3000');
      return;
    }
    final days = int.tryParse(_warrantyDays.text.trim()) ?? 0;
    if (days <= 0) {
      setState(() => _error = 'أدخل عدد أيام الضمان (مثلاً 7 أو 30).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final scope = AppScope.of(context);
    final ok = await scope.dispatch.acceptOffer(
      offerId: widget.offer.id,
      technicianId: widget.offer.technicianId,
      technicianName: widget.workshopName,
      initialPrice: parsed,
      partCondition: _condition.name,
      warrantyDays: days,
      warrantyNote: _warrantyNote.text.trim().isEmpty
          ? 'ضمان $days يوم'
          : _warrantyNote.text.trim(),
      deliveryType: _delivery.name,
      vendorNote: _vendorNotes.text.trim(),
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'فاتك الطلب أو انتهت المهلة.';
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال عرض السعر للعميل بنجاح.')),
    );
    widget.onDone();
  }

  Future<void> _reject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اعتذار عن الطلب؟'),
        content: const Text(
          'سيتم إسناد الطلب لورش أخرى. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('اعتذار'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AppScope.of(context).jobs.rejectOffer(widget.offer.id);
    widget.onDone();
  }

  String _mmss(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      child: SafeArea(
        child: StreamBuilder<Job?>(
          stream: AppScope.of(context).jobs.watchJob(widget.offer.jobId),
          builder: (context, snap) {
            final job = snap.data;
            final partName = (job?.partName.isNotEmpty == true)
                ? job!.partName
                : (widget.offer.partName.isNotEmpty
                    ? widget.offer.partName
                    : (widget.offer.serviceTitle ?? 'قطعة غيار'));
            final car = [
              if ((job?.carMake ?? widget.offer.carMake).isNotEmpty)
                job?.carMake ?? widget.offer.carMake,
              if ((job?.carModel ?? widget.offer.carModel).isNotEmpty)
                job?.carModel ?? widget.offer.carModel,
              if ((job?.carYear ?? '').isNotEmpty) '(${job!.carYear})',
            ].where((e) => e != null && e.toString().isNotEmpty).join(' ');
            final imageUrl = job?.partImageUrl ?? '';
            final note = job?.partNote ?? '';
            final address = job == null
                ? 'موقع تقريبي'
                : 'موقع التوصيل (يظهر بالكامل بعد قبول العميل)';
            final phone = job?.customerPhone.isNotEmpty == true
                ? _maskPhone(job!.customerPhone)
                : '0770 *** ****';
            final km = widget.offer.distanceKm;

            return Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: widget.onDone,
                            icon: const Icon(Icons.close),
                          ),
                          const Expanded(
                            child: Text(
                              'تقديم عرض السعر',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.azureTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'طلب #${widget.offer.jobId.length > 6 ? widget.offer.jobId.substring(0, 6).toUpperCase() : widget.offer.jobId}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF45464D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        children: [
                          // Incoming request card
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  color: AppColors.azureTint,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            children: [
                                              const TextSpan(
                                                  text: 'ينتهي العرض بعد '),
                                              TextSpan(
                                                text: _mmss(_left),
                                                style: const TextStyle(
                                                  color: AppColors.danger,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'القطعة المطلوبة',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.amberDeep,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  partName,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                    height: 1.3,
                                                  ),
                                                ),
                                                if (car.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children: [
                                                      _Chip(
                                                        icon: Icons
                                                            .directions_car_outlined,
                                                        label: car,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (imageUrl.isNotEmpty)
                                            GestureDetector(
                                              onTap: () => setState(
                                                  () => _showImage = true),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: SizedBox(
                                                  width: 72,
                                                  height: 72,
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      _DataUrlImage(
                                                          dataUrl: imageUrl),
                                                      const Align(
                                                        alignment: Alignment
                                                            .bottomRight,
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsets.all(4),
                                                          child: Icon(
                                                            Icons
                                                                .photo_camera,
                                                            size: 14,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.petrolTint,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on,
                                                  size: 18,
                                                  color: AppColors.amberDeep,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    address,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                if (km != null)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              999),
                                                    ),
                                                    child: Text(
                                                      '${km.toStringAsFixed(1)} كم',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.call,
                                                    size: 16,
                                                    color: Color(0xFF45464D)),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'هاتف الزبون: $phone',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF45464D),
                                                  ),
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                        0xFFE5EEFF),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: const Text(
                                                    'يظهر بعد القبول',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF45464D),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (note.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.azureTint
                                                .withValues(alpha: 0.45),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.info_outline,
                                                  size: 16, color: AppColors.amberDeep),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text.rich(
                                                  TextSpan(
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      height: 1.45,
                                                      color: Color(0xFF45464D),
                                                    ),
                                                    children: [
                                                      const TextSpan(
                                                        text: 'ملاحظة الزبون: ',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: AppColors.ink,
                                                        ),
                                                      ),
                                                      TextSpan(text: note),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Quote form
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.amber
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.request_quote_outlined,
                                        color: AppColors.amberDeep,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'تقديم عرض السعر الفوري',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.petrolTint,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'استجابة سريعة',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.emerald,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'حالة القطعة المتوفرة بالورشة:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _ConditionTile(
                                  selected: _condition == _PartCondition.oem,
                                  title: 'أصلي وكالة جديد (Genuine OEM)',
                                  subtitle:
                                      'مستورد كوري - كارتون المصنع مع رقم القطعة',
                                  trailing: const Icon(Icons.verified,
                                      color: AppColors.emerald, size: 20),
                                  onTap: () => setState(
                                      () => _condition = _PartCondition.oem),
                                ),
                                const SizedBox(height: 8),
                                _ConditionTile(
                                  selected:
                                      _condition == _PartCondition.aftermarket,
                                  title: 'كوري درجة أولى مضمون',
                                  subtitle:
                                      'مطابق لمعايير الوكالة بكفاءة عالية',
                                  trailing: _Tag('تجاري ممتاز'),
                                  onTap: () => setState(() =>
                                      _condition = _PartCondition.aftermarket),
                                ),
                                const SizedBox(height: 8),
                                _ConditionTile(
                                  selected: _condition == _PartCondition.used,
                                  title: 'مستعمل تفصيخ أصلي بفحص',
                                  subtitle:
                                      'مفكوك من مركبة سليمة ومفحوص ديناميكياً',
                                  trailing: _Tag('مفحوص'),
                                  onTap: () => setState(
                                      () => _condition = _PartCondition.used),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'سعر بيع القطعة للزبون (د.ع):',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _price,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '145000',
                                    filled: true,
                                    fillColor: AppColors.petrolTint,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixText: 'د.ع',
                                    suffixStyle: const TextStyle(
                                      color: AppColors.amberDeep,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    helperText:
                                        'الحد الأدنى 3000 وينتهي بـ 000',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'مدة الضمان (بالأيام) — الورشة تحددها:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _warrantyDays,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    hintText: 'مثال: 7 أو 30 أو 90',
                                    filled: true,
                                    fillColor: AppColors.petrolTint,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixText: 'يوم',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _warrantyNote,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    hintText:
                                        'وصف الضمان (اختياري) مثل: استبدال فوري / كفالة تشغيل',
                                    filled: true,
                                    fillColor: AppColors.petrolTint,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'طريقة التسليم:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _ConditionTile(
                                  selected:
                                      _delivery == _DeliveryType.delivery,
                                  title: 'توصيل مباشر لموقع الزبون',
                                  subtitle: 'الوصول حسب المسافة والازدحام',
                                  trailing: const Text(
                                    'مجاني',
                                    style: TextStyle(
                                      color: AppColors.emerald,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onTap: () => setState(() =>
                                      _delivery = _DeliveryType.delivery),
                                ),
                                const SizedBox(height: 8),
                                _ConditionTile(
                                  selected: _delivery == _DeliveryType.pickup,
                                  title: 'استلام يدوي من مقر الورشة',
                                  subtitle: 'القطعة جاهزة للاستلام',
                                  trailing: const Icon(Icons.store_outlined,
                                      size: 18, color: Color(0xFF45464D)),
                                  onTap: () => setState(
                                      () => _delivery = _DeliveryType.pickup),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'ملاحظات إضافية للزبون (اختياري):',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _vendorNotes,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    hintText:
                                        'مثال: متوفر بالكرتون الأصلي، الفني يفحص بالموقع…',
                                    filled: true,
                                    fillColor: AppColors.petrolTint,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5EEFF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'المبلغ الإجمالي',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF45464D),
                                              ),
                                            ),
                                            Text(
                                              _price.text.trim().isEmpty
                                                  ? '—'
                                                  : formatIqd(
                                                      double.tryParse(
                                                            _price.text
                                                                .replaceAll(
                                                                    ',', '')
                                                                .trim(),
                                                          ) ??
                                                          0,
                                                    ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.payments_outlined,
                                                  size: 14, color: AppColors.emerald),
                                              SizedBox(width: 4),
                                              Text(
                                                'كاش عند الاستلام',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.emerald,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'ضمان: ${_warrantyDays.text.isEmpty ? '—' : '${_warrantyDays.text} يوم'} · $_conditionLabel',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF45464D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _busy
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'إرسال عرض السعر للعميل',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(Icons.send_rounded,
                                                  size: 20),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _busy ? null : _reject,
                                  icon: const Icon(Icons.cancel_outlined,
                                      color: AppColors.danger),
                                  label: const Text(
                                    'اعتذار عن عدم توفر القطعة حالياً',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.petrolTint,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.notifications_active_outlined,
                                    color: AppColors.amberDeep),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'تنبيه سرعة الاستجابة',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'بمجرد قبول العميل لعرضك، يصلك إشعار مع رقم الهاتف والموقع الدقيق لإرسال القطعة والدفع كاش.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.45,
                                          color: Color(0xFF45464D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_showImage && imageUrl.isNotEmpty)
                  _ImageLightbox(
                    dataUrl: imageUrl,
                    caption: partName,
                    onClose: () => setState(() => _showImage = false),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _maskPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return '***';
    return '${digits.substring(0, 4)} *** ${digits.substring(digits.length - 2)}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5EEFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.ink),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE5EEFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Color(0xFF45464D)),
      ),
    );
  }
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEFF4FF) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? Colors.black.withValues(alpha: 0.2)
                  : const Color(0xFFE5EEFF),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: selected ? Colors.black : const Color(0xFF76777D),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF45464D),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _DataUrlImage extends StatelessWidget {
  const _DataUrlImage({required this.dataUrl});

  final String dataUrl;

  @override
  Widget build(BuildContext context) {
    try {
      final comma = dataUrl.indexOf(',');
      final b64 = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
      return Image.memory(base64Decode(b64), fit: BoxFit.cover);
    } catch (_) {
      return const ColoredBox(color: Color(0xFFEFF4FF));
    }
  }
}

class _ImageLightbox extends StatelessWidget {
  const _ImageLightbox({
    required this.dataUrl,
    required this.caption,
    required this.onClose,
  });

  final String dataUrl;
  final String caption;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'صورة القطعة من الزبون',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _DataUrlImage(dataUrl: dataUrl),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(caption, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: onClose,
                        child: const Text('إغلاق المعاينة'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
