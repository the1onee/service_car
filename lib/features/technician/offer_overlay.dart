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

/// طابور عروض واردة: تمرير بين الطلبات + سحب لإبعاد مؤقت.
class OfferOverlay extends StatefulWidget {
  const OfferOverlay({
    super.key,
    required this.offers,
    required this.technicianName,
    required this.onSoftDismiss,
    required this.onConsumed,
  });

  final List<JobOffer> offers;
  final String technicianName;
  /// إبعاد مؤقت (سحب) بدون رفض نهائي.
  final ValueChanged<String> onSoftDismiss;
  /// بعد تقديم سعر / رفض / فقدان العرض.
  final ValueChanged<String> onConsumed;

  @override
  State<OfferOverlay> createState() => _OfferOverlayState();
}

class _OfferOverlayState extends State<OfferOverlay> {
  late final PageController _page;

  @override
  void initState() {
    super.initState();
    _page = PageController();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OfferOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.offers.isEmpty) return;
    if (_page.hasClients && _page.page != null) {
      final idx = _page.page!.round().clamp(0, widget.offers.length - 1);
      if (idx != _page.page!.round()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_page.hasClients) {
            _page.jumpToPage(idx);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offers = widget.offers;
    if (offers.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              offers.length == 1
                  ? 'طلب وارد'
                  : 'طلبات واردة — مرّر للاختيار أو اسحب للإبعاد',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (offers.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${offers.length} طلبات',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: offers.length,
                itemBuilder: (context, i) {
                  final offer = offers[i];
                  return Dismissible(
                    key: ValueKey(offer.id),
                    direction: DismissDirection.horizontal,
                    onDismissed: (_) => widget.onSoftDismiss(offer.id),
                    background: const _SwipeHint(
                      alignment: Alignment.centerRight,
                      label: 'إبعاد',
                    ),
                    secondaryBackground: const _SwipeHint(
                      alignment: Alignment.centerLeft,
                      label: 'إبعاد',
                    ),
                    child: _OfferCard(
                      offer: offer,
                      index: i,
                      total: offers.length,
                      technicianName: widget.technicianName,
                      onConsumed: () => widget.onConsumed(offer.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.alignment, required this.label});

  final Alignment alignment;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate.withValues(alpha: 0.35),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _OfferCard extends StatefulWidget {
  const _OfferCard({
    required this.offer,
    required this.index,
    required this.total,
    required this.technicianName,
    required this.onConsumed,
  });

  final JobOffer offer;
  final int index;
  final int total;
  final String technicianName;
  final VoidCallback onConsumed;

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
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
        widget.onConsumed();
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
      if (n <= 0) _timer?.cancel();
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
      widget.onConsumed();
      return;
    }
    widget.onConsumed();
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final tow = offer.hasTowDetails;
    final wash = !tow && offer.hasWashDetails;
    final oil = !tow && !wash && offer.hasOilDetails;
    return Center(
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
                      if (widget.total > 1)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: StatusPill(
                            label: '${widget.index + 1}/${widget.total}',
                            color: AppColors.inkSoft,
                            background: AppColors.recessed,
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
                    child: Text(_busy ? 'جارٍ الإرسال…' : 'تقديم عرض السعر'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await AppScope.of(context)
                                .jobs
                                .rejectOffer(offer.id);
                            widget.onConsumed();
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
    );
  }
}
