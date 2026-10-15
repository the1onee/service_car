import 'dart:async';

import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/app_snackbar.dart';
import 'package:barrr/core/app_sound.dart';
import 'package:barrr/core/app_svg_icons.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/customer/tow_job_details.dart';
import 'package:barrr/features/customer/wash_job_details.dart';
import 'package:barrr/features/oil_workshop/oil_job_details.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/technician/tech_job_details.dart';
import 'package:barrr/models/job_offer.dart';

/// طابور عروض واردة لمزوّد الخدمة (فني / ورشة زيوت / …).
///
/// التمرير الأفقي عبر [PageView] فقط؛ الإبعاد المؤقت بزر صريح لتجنب
/// تضارب الإيماءات مع [Dismissible].
class OfferOverlay extends StatefulWidget {
  const OfferOverlay({
    super.key,
    required this.offers,
    required this.providerName,
    required this.onSoftDismiss,
    required this.onConsumed,
  });

  final List<JobOffer> offers;
  final String providerName;

  /// إبعاد مؤقت (زر صريح) بدون رفض نهائي.
  final ValueChanged<String> onSoftDismiss;

  /// بعد تقديم سعر / رفض / فقدان العرض.
  final ValueChanged<String> onConsumed;

  @override
  State<OfferOverlay> createState() => _OfferOverlayState();
}

class _OfferOverlayState extends State<OfferOverlay> {
  late final PageController _page;
  var _currentPage = 0;

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
    if (widget.offers.isEmpty) {
      _currentPage = 0;
      return;
    }

    final maxIdx = widget.offers.length - 1;
    final fromController = _page.hasClients && _page.page != null
        ? _page.page!.round()
        : _currentPage;
    final safeIdx = fromController.clamp(0, maxIdx);

    if (safeIdx != _currentPage) {
      _currentPage = safeIdx;
    }

    if (_page.hasClients &&
        (_page.page == null || _page.page!.round() != safeIdx)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_page.hasClients) return;
        final again = safeIdx.clamp(0, widget.offers.length - 1);
        if (_page.page?.round() != again) {
          _page.jumpToPage(again);
        }
        if (_currentPage != again) {
          setState(() => _currentPage = again);
        }
      });
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.offers.length) return;
    _page.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String _headerLabel(List<JobOffer> offers) {
    final allOil = offers.every((o) => o.hasOilDetails);
    if (offers.length == 1) {
      return allOil ? 'طلب زيت وارد' : 'طلب وارد';
    }
    return allOil
        ? 'طلبات زيت — مرّر أو استخدم الأسهم'
        : 'طلبات واردة — مرّر أو استخدم الأسهم';
  }

  @override
  Widget build(BuildContext context) {
    final offers = widget.offers;
    if (offers.isEmpty) return const SizedBox.shrink();

    final page = _currentPage.clamp(0, offers.length - 1);
    final multi = offers.length > 1;

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              _headerLabel(offers),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (multi)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'طلب ${page + 1} من ${offers.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    controller: _page,
                    physics: const BouncingScrollPhysics(),
                    itemCount: offers.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, i) {
                      final offer = offers[i];
                      return _OfferCard(
                        key: ValueKey(offer.id),
                        offer: offer,
                        index: i,
                        total: offers.length,
                        providerName: widget.providerName,
                        onSoftDismiss: () => widget.onSoftDismiss(offer.id),
                        onConsumed: () => widget.onConsumed(offer.id),
                      );
                    },
                  ),
                  if (multi) ...[
                    PositionedDirectional(
                      start: 4,
                      child: _NavArrow(
                        icon: Icons.chevron_left_rounded,
                        enabled: page > 0,
                        onTap: () => _goTo(page - 1),
                        tooltip: 'الطلب السابق',
                      ),
                    ),
                    PositionedDirectional(
                      end: 4,
                      child: _NavArrow(
                        icon: Icons.chevron_right_rounded,
                        enabled: page < offers.length - 1,
                        onTap: () => _goTo(page + 1),
                        tooltip: 'الطلب التالي',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (multi)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _PageDots(
                  count: offers.length,
                  index: page,
                  onDotTap: _goTo,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: enabled ? 0.45 : 0.2),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, color: Colors.white.withValues(alpha: enabled ? 1 : 0.35)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.index,
    required this.onDotTap,
  });

  final int count;
  final int index;
  final ValueChanged<int> onDotTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GestureDetector(
            onTap: () => onDotTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _OfferCard extends StatefulWidget {
  const _OfferCard({
    super.key,
    required this.offer,
    required this.index,
    required this.total,
    required this.providerName,
    required this.onSoftDismiss,
    required this.onConsumed,
  });

  final JobOffer offer;
  final int index;
  final int total;
  final String providerName;
  final VoidCallback onSoftDismiss;
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
          technicianName: widget.providerName,
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
    AppSnackBar.showSuccess(context, 'تم إرسال عرضك للعميل');
    AppSoundService.playOfferPenguin();
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
                      AppSvgIcons.offerIcon(isWorkshop: oil, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: oil
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'طلب تبديل زيت جديد',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.amberDeep,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    offer.oilDisplayTitle,
                                    style: const TextStyle(
                                      color: AppColors.amberDeep,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                tow
                                    ? 'طلب سطحة'
                                    : wash
                                        ? 'طلب غسيل'
                                        : 'طلب خدمة جديد',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      if (widget.total > 1)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 4),
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
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'إبعاد مؤقت',
                        onPressed: _busy ? null : widget.onSoftDismiss,
                        icon: const Icon(Icons.close_rounded),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.inkSoft,
                          backgroundColor: AppColors.recessed,
                        ),
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
                      backgroundColor:
                          oil ? AppColors.amberDeep : AppColors.slate,
                    ),
                    child: Text(
                      _busy
                          ? 'جارٍ الإرسال…'
                          : (oil ? 'إرسال العرض' : 'تقديم عرض السعر'),
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
                            widget.onConsumed();
                          },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: oil ? AppColors.danger : null,
                      side: oil
                          ? const BorderSide(color: AppColors.danger)
                          : null,
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
