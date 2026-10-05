import 'dart:async';

import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/customer/tow_job_details.dart';
import 'package:barrr/features/customer/wash_job_details.dart';
import 'package:barrr/features/oil_workshop/oil_job_details.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/technician/tech_job_details.dart';
import 'package:barrr/models/job_offer.dart';

class OfferOverlay extends StatefulWidget {
  const OfferOverlay({
    super.key,
    required this.offer,
    required this.technicianName,
    required this.onDone,
  });

  final JobOffer offer;
  final String technicianName;
  final VoidCallback onDone;

  @override
  State<OfferOverlay> createState() => _OfferOverlayState();
}

class _OfferOverlayState extends State<OfferOverlay> {
  late int _left;
  Timer? _timer;
  void Function()? _stopLostWatch;
  var _watching = false;
  final _price = TextEditingController();
  bool _busy = false;
  String? _error;
  late final bool _openEnded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_watching) return;
    _watching = true;
    _stopLostWatch = AppScope.of(context).jobs.watchLostOffer(
      jobId: widget.offer.jobId,
      offerId: widget.offer.id,
      technicianId: widget.offer.technicianId,
      onLost: () {
        if (!mounted) return;
        widget.onDone();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _openEnded = widget.offer.isOpenEnded;
    _left = widget.offer.remainingSeconds();
    if (_openEnded) return;
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
    _stopLostWatch?.call();
    _timer?.cancel();
    _price.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final parsed = double.tryParse(_price.text.replaceAll(',', '').trim());
    final amountError = AppConstants.serviceAmountError(parsed);
    if (amountError != null || parsed == null) {
      setState(() => _error =
          amountError ?? 'أدخل مبلغاً ينتهي بـ 000، والحد الأدنى 3000');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AppScope.of(context).dispatch.acceptOffer(
          offerId: widget.offer.id,
          technicianId: widget.offer.technicianId,
          technicianName: widget.technicianName,
          initialPrice: parsed,
        );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = _openEnded
            ? 'تعذر إرسال العرض. قد يكون العميل قبل عرضاً آخر.'
            : 'فاتك الطلب أو انتهت المهلة.';
      });
      widget.onDone();
      return;
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final tow = offer.hasTowDetails;
    final wash = !tow && offer.hasWashDetails;
    final oil = !tow && !wash && offer.hasOilDetails;
    return Material(
      color: Colors.black54,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
          child: Card(
            margin: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tow
                                ? 'طلب سطحة'
                                : wash
                                    ? 'طلب غسيل'
                                    : (oil
                                        ? 'طلب تبديل زيت'
                                        : 'طلب خدمة جديد'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!_openEnded)
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.amberTint,
                            child: Text(
                              '$_left',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.amberDeep,
                              ),
                            ),
                          )
                        else
                          const StatusPill(
                            label: 'بدون مهلة',
                            color: AppColors.emeraldDeep,
                            background: AppColors.emeraldTint,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (tow)
                      TowJobDetailsCard.fromOffer(offer, compact: true)
                    else if (wash)
                      WashJobDetailsCard.fromOffer(offer, compact: true)
                    else if (oil)
                      OilJobDetailsCard.fromOffer(offer, compact: true)
                    else
                      TechJobDetailsCard.fromOffer(offer, compact: true),
                    const SizedBox(height: 10),
                    Text(
                      _openEnded
                          ? 'أرسل سعرك متى جاهز. الموقع والهاتف يظهران بعد قبول العميل.'
                          : 'الموقع تقريبي ورقم الهاتف مخفي حتى يقبل العميل.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: AppStrings.initialPrice,
                        hintText: '5000',
                        helperText: 'الحد الأدنى 3000 وينتهي بـ 000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _busy ? null : _accept,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppColors.slate,
                      ),
                      child: Text(
                        _busy
                            ? 'جارٍ الإرسال…'
                            : (oil ? 'تقديم عرض السعر' : 'تقديم عرض السعر'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await AppScope.of(context)
                                  .jobs
                                  .rejectOffer(offer.id);
                              widget.onDone();
                            },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      child: const Text(AppStrings.reject),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
