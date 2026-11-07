import 'dart:async';

import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/app_snackbar.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/core/user_error.dart';
import 'package:barrr/features/customer/parts_offers_section.dart';
import 'package:barrr/features/customer/quote_compare_list.dart';
import 'package:barrr/features/customer/tow_job_details.dart';
import 'package:barrr/features/customer/wash_job_details.dart';
import 'package:barrr/features/jobs/rating_sheet.dart';
import 'package:barrr/features/oil_workshop/oil_job_details.dart';
import 'package:barrr/features/shared/app_network_or_data_image.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/services/job_repository.dart';

class CustomerJobPanel extends StatefulWidget {
  const CustomerJobPanel({
    super.key,
    required this.job,
    required this.me,
    this.fullscreen = false,
  });

  final Job job;
  final AppUser me;

  /// شاشة كاملة (طلب قطع على الرئيسية) بدل ورقة سفلية فوق الخريطة.
  final bool fullscreen;

  @override
  State<CustomerJobPanel> createState() => _CustomerJobPanelState();
}

class _CustomerJobPanelState extends State<CustomerJobPanel> {
  Timer? _waitRetry;

  Job get job => widget.job;
  AppUser get me => widget.me;

  @override
  void initState() {
    super.initState();
    _syncWaitRetry();
  }

  @override
  void didUpdateWidget(covariant CustomerJobPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.job.status != job.status || oldWidget.job.id != job.id) {
      _syncWaitRetry();
    }
  }

  @override
  void dispose() {
    _waitRetry?.cancel();
    super.dispose();
  }

  void _syncWaitRetry() {
    _waitRetry?.cancel();
    _waitRetry = null;
    if (job.status != JobStatus.noTechnician) return;
    _waitRetry = Timer.periodic(const Duration(seconds: 50), (_) async {
      if (!mounted || job.status != JobStatus.noTechnician) return;
      try {
        await AppScope.of(context).jobs.maybeRedispatch(job.id);
      } catch (_) {}
    });
  }

  String get _serviceLabel {
    if (job.isTowOrder) return job.serviceTitle ?? 'سطحة';
    if (job.isWashOrder) return job.washDisplayTitle;
    if (job.isOilOrder) return job.oilDisplayTitle;
    return job.serviceTitle ?? job.serviceId;
  }

  bool get _isFullscreenWaiting =>
      widget.fullscreen &&
      (job.status == JobStatus.noTechnician ||
          job.status == JobStatus.dispatching);

  @override
  Widget build(BuildContext context) {
    if (_isFullscreenWaiting) {
      return _buildFullscreenWaiting(context);
    }

    final fullscreen = widget.fullscreen;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!fullscreen)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.outlineStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        Text(_title(job.status),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          _serviceLabel,
          style: TextStyle(
            color: (job.isOilOrder || job.isWashOrder || job.isTowOrder)
                ? AppColors.amberDeep
                : AppColors.inkSoft,
            fontWeight: (job.isOilOrder || job.isWashOrder || job.isTowOrder)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
        if (job.isTowOrder) ...[
          const SizedBox(height: 10),
          TowJobDetailsCard.fromJob(job, compact: true, showPhone: true),
        ] else if (job.isWashOrder) ...[
          const SizedBox(height: 10),
          WashJobDetailsCard.fromJob(job, compact: true, showPhone: true),
        ] else if (job.isOilOrder) ...[
          const SizedBox(height: 10),
          OilJobDetailsCard.fromJob(job, compact: true, showPhone: true),
        ] else if (job.vehicleTypeTitle != null &&
            job.vehicleTypeTitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'نوع السيارة: ${job.vehicleTypeTitle}',
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
        ],
        if (_showSteps(job.status)) ...[
          const SizedBox(height: 14),
          _Steps(
            status: job.status,
            isParts: job.isPartsOrder,
            isWash: job.isWashOrder,
            isTow: job.isTowOrder,
          ),
        ],
        const SizedBox(height: 14),
        ..._body(context),
      ],
    );

    final scroll = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, fullscreen ? 16 : 10, 16, 20),
      child: body,
    );

    if (fullscreen) {
      return Material(
        color: AppColors.canvas,
        child: SafeArea(child: scroll),
      );
    }

    return Material(
      color: AppColors.surface,
      elevation: 16,
      shadowColor: AppColors.slate.withValues(alpha: 0.16),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.62),
        child: scroll,
      ),
    );
  }

  Widget _buildFullscreenWaiting(BuildContext context) {
    final jobs = AppScope.of(context).jobs;
    final searching = job.status == JobStatus.dispatching;
    final car = job.carSummary.trim();
    final part = job.partName.trim();
    final specialty = job.specialtyAr.trim();
    final address = job.deliveryAddress.trim();

    return Material(
      color: AppColors.canvas,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.amberTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      searching
                          ? Icons.radar_rounded
                          : Icons.hourglass_top_rounded,
                      color: AppColors.amberDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(job.status),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _serviceLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.amberDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.outline),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.slate.withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: [
                                  AppColors.amberTint,
                                  AppColors.amber.withValues(alpha: 0.35),
                                ],
                              ),
                            ),
                            child: Icon(
                              searching
                                  ? Icons.search_rounded
                                  : Icons.storefront_outlined,
                              size: 40,
                              color: AppColors.amberDeep,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            searching
                                ? 'نبحث عن ورش مناسبة لطلبك'
                                : 'لا يوجد مزوّد متاح الآن',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            searching
                                ? 'سيصلك إشعار فور وصول عروض جديدة.'
                                : AppStrings.waitingForProviderBody,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.55,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          if (searching) ...[
                            const SizedBox(height: 18),
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: AppColors.amberDeep,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (car.isNotEmpty ||
                        part.isNotEmpty ||
                        specialty.isNotEmpty ||
                        address.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'تفاصيل الطلب',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (specialty.isNotEmpty)
                              _waitingDetailRow(
                                Icons.category_outlined,
                                'الاختصاص',
                                specialty,
                              ),
                            if (car.isNotEmpty)
                              _waitingDetailRow(
                                Icons.directions_car_outlined,
                                'المركبة',
                                car,
                              ),
                            if (part.isNotEmpty)
                              _waitingDetailRow(
                                Icons.settings_outlined,
                                'القطعة',
                                part,
                              ),
                            if (address.isNotEmpty)
                              _waitingDetailRow(
                                Icons.location_on_outlined,
                                'التوصيل',
                                address,
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.azureTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.autorenew_rounded,
                            size: 20,
                            color: AppColors.azure,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'نعيد المحاولة تلقائياً كل فترة قصيرة.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () => jobs.maybeRedispatch(job.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.slate,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      AppStrings.retrySearchProviders,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (job.customerCanCancel) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => _confirmCancel(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        backgroundColor: AppColors.dangerTint,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        AppStrings.cancelJob,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _waitingDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _showSteps(JobStatus s) {
    if (job.isPartsOrder) {
      return s == JobStatus.quoted ||
          s == JobStatus.enRoute ||
          s == JobStatus.arrived ||
          s == JobStatus.inProgress;
    }
    if (job.isWashOrder || job.isTowOrder) {
      return s == JobStatus.providerQueued ||
          s == JobStatus.quoted ||
          s == JobStatus.enRoute ||
          s == JobStatus.arrived ||
          s == JobStatus.inProgress;
    }
    return s == JobStatus.providerQueued ||
        s == JobStatus.quoted ||
        s == JobStatus.enRoute ||
        s == JobStatus.arrived ||
        s == JobStatus.finalQuote ||
        s == JobStatus.inProgress;
  }

  String _title(JobStatus s) {
    final parts = job.isPartsOrder;
    final oil = job.isOilOrder;
    final wash = job.isWashOrder;
    final tow = job.isTowOrder;
    switch (s) {
      case JobStatus.dispatching:
      case JobStatus.offerPending:
        if (wash) return 'بانتظار عروض الغسيل';
        if (tow) return 'بانتظار عروض السطحة';
        return job.isEmergency
            ? AppStrings.searching
            : AppStrings.collectingQuotes;
      case JobStatus.comparing:
        if (wash) return 'بانتظار عروض الغسيل';
        if (tow) return 'بانتظار عروض السطحة';
        return AppStrings.compareQuotes;
      case JobStatus.providerQueued:
        if (oil) return 'ورشة الزيوت مشغولة بطلب آخر';
        if (wash) return 'المغسل مشغول بطلب آخر';
        if (tow) return 'السطحة مشغولة بطلب آخر';
        return 'الفني مشغول بطلب آخر';
      case JobStatus.quoted:
        if (parts) return 'الورشة تجهّز طلبك';
        if (oil) return 'ورشة الزيوت قبلت الطلب';
        if (wash) return 'مغسل قبل الطلب';
        if (tow) return 'سطحة قبلت الطلب';
        return 'فني قبل الطلب';
      case JobStatus.enRoute:
        if (parts) return 'الورشة تجهّز القطعة';
        if (oil) return 'ورشة الزيوت في الطريق إليك';
        if (wash) return 'مغسل في الطريق';
        if (tow) return 'سطحة في الطريق';
        return 'الفني في الطريق إليك';
      case JobStatus.arrived:
        if (parts) return 'الورشة بصدد الإرسال';
        if (oil) return 'ورشة الزيوت وصلت — جاري التبديل';
        if (wash) return 'المغسل وصل — جاري الغسيل';
        if (tow) return 'السطحة وصلت — جاري النقل';
        return 'الفني وصل — جاري الفحص';
      case JobStatus.finalQuote:
        if (parts) return 'القطعة في الطريق إليك';
        if (oil) return 'جاري تبديل الزيت';
        if (wash) return 'جاري الغسيل';
        if (tow) return 'جاري النقل';
        return 'السعر النهائي بانتظار موافقتك';
      case JobStatus.inProgress:
        if (parts) return 'القطعة في الطريق — أكّد الاستلام';
        if (oil) return 'جاري تبديل الزيت';
        if (wash) return 'جاري الغسيل';
        if (tow) return 'جاري النقل';
        return 'جاري العمل';
      case JobStatus.completed:
        if (parts) return 'تم استلام القطعة';
        if (oil) return 'تم تبديل الزيت';
        if (wash) return 'تم الغسيل';
        if (tow) return 'تم النقل';
        return 'انتهت المهمة';
      case JobStatus.noTechnician:
        return AppStrings.waitingForProviderTitle;
      case JobStatus.cancelled:
        return 'تم إلغاء الطلب';
      case JobStatus.rated:
        return 'شكراً لتقييمك';
    }
  }

  List<Widget> _body(BuildContext context) {
    final jobs = AppScope.of(context).jobs;
    final items = List<Widget>.of(_statusBody(context, jobs));
    if (job.customerCanCancel) {
      items.add(const SizedBox(height: 10));
      items.add(
        OutlinedButton(
          onPressed: () => _confirmCancel(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: Color(0xFFFECACA)),
            backgroundColor: AppColors.dangerTint,
            minimumSize: const Size.fromHeight(46),
          ),
          child: const Text(AppStrings.cancelJob),
        ),
      );
    }
    return items;
  }

  List<Widget> _walletSwitch(BuildContext context) {
    final bill = job.billAmount;
    final balance = me.walletBalance;
    if (balance <= 0) return const [];
    final reserve = bill <= 0 ? 0.0 : (balance < bill ? balance : bill);
    return [
      const SizedBox(height: 12),
      Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: job.useWallet,
          title: Text('استخدم الرصيد (${formatIqd(balance)})'),
          subtitle: job.useWallet
              ? Text('يُخصم ${formatIqd(job.walletReserve)} من المطلوب نقداً')
              : null,
          onChanged: (use) {
            AppScope.of(context).jobs.setUseWallet(
                  jobId: job.id,
                  use: use,
                  reserve: use ? reserve : 0,
                );
          },
        ),
      ),
    ];
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final reason = await _askReason(context, 'إلغاء الطلب', 'سبب الإلغاء (اختياري)');
    if (reason == null || !context.mounted) return;
    try {
      await AppScope.of(context).jobs.customerCancelJob(job.id, reason: reason);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  List<Widget> _statusBody(BuildContext context, JobRepository jobs) {
    switch (job.status) {
      case JobStatus.dispatching:
      case JobStatus.offerPending:
        final head = <Widget>[
          if (job.cancelledBy == 'technician') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amberTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'انسحب المزود — جاري البحث عن بديل.',
                style: TextStyle(
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ];
        if (job.isEmergency) {
          return [
            ...head,
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text('بانتظار القبول'),
          ];
        }
        if (job.isPartsOrder) {
          return [
            ...head,
            PartsOffersSection(job: job, selectable: true),
          ];
        }
        if (job.isOilOrder) {
          return [
            ...head,
            const Text(
              'اختر عرض ورشة الزيوت عندما يصل — بدون مهلة زمنية.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 12),
            QuoteCompareList(job: job, selectable: true),
          ];
        }
        if (job.isWashOrder) {
          return [
            ...head,
            const Text(
              'اختر عرض الغسيل عندما يصل — بدون مهلة زمنية.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 12),
            QuoteCompareList(job: job, selectable: true),
          ];
        }
        if (job.isTowOrder) {
          return [
            ...head,
            const Text(
              'اختر عرض السطحة عندما يصل — بدون مهلة زمنية.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 12),
            QuoteCompareList(job: job, selectable: true),
          ];
        }
        if (job.isTechnicianJob) {
          return [
            ...head,
            const Text(
              'اختر عرض الفني عندما يصل — بدون مهلة زمنية.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 12),
            QuoteCompareList(job: job, selectable: true),
          ];
        }
        return [
          ...head,
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          const Text('بانتظار العروض'),
          const SizedBox(height: 16),
          QuoteCompareList(job: job, selectable: false),
        ];
      case JobStatus.comparing:
        if (job.isPartsOrder) {
          return [
            PartsOffersSection(job: job, selectable: true),
          ];
        }
        return [
          QuoteCompareList(job: job, selectable: true),
        ];
      case JobStatus.providerQueued:
        final who = job.isOilOrder
            ? 'ورشة الزيوت'
            : job.isWashOrder
                ? 'المغسل'
                : job.isTowOrder
                    ? 'السطحة'
                    : 'الفني';
        return [
          _liveCard('$who ينهي طلباً آخر الآن، ثم يتجه إليك مباشرة'),
          const SizedBox(height: 10),
          const Text(
            'يمكنك الاتصال أو إرسال موقعك، أو إلغاء الطلب، أو الانتظار.',
            style: TextStyle(color: AppColors.inkSoft, height: 1.45),
          ),
          const SizedBox(height: 10),
          _techLine(),
          const SizedBox(height: 8),
          _priceLine('السعر المبدئي', job.initialPrice),
        ];
      case JobStatus.quoted:
        if (job.isPartsOrder) {
          return _partsPreparing(jobs);
        }
        return [
          _techLine(),
          const SizedBox(height: 10),
          _priceLine('السعر المبدئي', job.initialPrice),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _accept(
              context,
              () => jobs.customerAcceptQuote(job.id),
              'تعذّر قبول الطلب.',
            ),
            child: Text(
              job.isOilOrder || job.isWashOrder || job.isTowOrder
                  ? 'قبول الطلب وبدء التوجه'
                  : 'قبول السعر',
            ),
          ),
        ];
      case JobStatus.enRoute:
        if (job.isPartsOrder) {
          return _partsPreparing(jobs);
        }
        return [
          _liveCard(
            job.isOilOrder
                ? 'ورشة الزيوت في الطريق'
                : job.isWashOrder
                    ? 'مغسل في الطريق'
                    : job.isTowOrder
                        ? 'سطحة في الطريق'
                        : 'الفني في الطريق',
          ),
          const SizedBox(height: 10),
          _techLine(),
          const SizedBox(height: 8),
          _priceLine('السعر المبدئي', job.initialPrice),
        ];
      case JobStatus.arrived:
        if (job.isPartsOrder) {
          return _partsPreparing(jobs);
        }
        return [
          _liveCard(
            job.isOilOrder
                ? 'جاري تبديل الزيت'
                : job.isWashOrder
                    ? 'جاري الغسيل'
                    : job.isTowOrder
                        ? 'جاري النقل'
                        : 'جاري الفحص',
          ),
          const SizedBox(height: 10),
          _techLine(),
        ];
      case JobStatus.finalQuote:
        if (job.isPartsOrder) {
          return _partsReceive(context, jobs);
        }
        // غسيل / سطحة / زيت: لا موافقة على سعر نهائي.
        if (job.isWashOrder || job.isTowOrder || job.isOilOrder) {
          return [
            _liveCard(
              job.isOilOrder
                  ? 'جاري تبديل الزيت'
                  : job.isTowOrder
                      ? 'جاري النقل'
                      : 'جاري الغسيل',
            ),
            const SizedBox(height: 10),
            _techLine(),
            const SizedBox(height: 8),
            _priceLine(
              'السعر المتفق',
              job.billAmount > 0 ? job.billAmount : job.initialPrice,
            ),
          ];
        }
        return [
          _techLine(),
          const SizedBox(height: 10),
          FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('السعر النهائي المتفق',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  job.finalPrice == null ? '-' : formatIqd(job.finalPrice!),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emeraldDeep,
                  ),
                ),
              ],
            ),
          ),
          if (job.warranty.enabled) ...[
            const SizedBox(height: 10),
            StatusPill(
              label: warrantyLabel(job.warranty),
              icon: Icons.verified_user_outlined,
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => _accept(
              context,
              () => jobs.customerAcceptFinal(job.id),
              'تعذّر قبول السعر.',
            ),
            child: const Text('قبول السعر'),
          ),
          ..._walletSwitch(context),
        ];
      case JobStatus.inProgress:
        if (job.isPartsOrder) {
          return _partsReceive(context, jobs);
        }
        return [
          _liveCard(
            job.isOilOrder
                ? 'جاري تبديل الزيت'
                : job.isWashOrder
                    ? 'جاري الغسيل'
                    : job.isTowOrder
                        ? 'جاري النقل'
                        : 'العمل جارٍ',
          ),
          if (job.isWashOrder || job.isTowOrder || job.isOilOrder) ...[
            const SizedBox(height: 10),
            _techLine(),
            const SizedBox(height: 8),
            _priceLine(
              'السعر المتفق',
              job.billAmount > 0 ? job.billAmount : job.initialPrice,
            ),
          ] else if (job.warranty.enabled) ...[
            const SizedBox(height: 10),
            StatusPill(
                label: warrantyLabel(job.warranty),
                icon: Icons.verified_user_outlined),
          ],
          ..._walletSwitch(context),
        ];
      case JobStatus.completed:
        return [
          _priceLine('المبلغ المستلم', job.receivedAmount),
          if (job.warranty.enabled) ...[
            const SizedBox(height: 8),
            StatusPill(
                label: warrantyLabel(job.warranty),
                icon: Icons.verified_user_outlined),
          ],
          const SizedBox(height: 12),
          if (job.ratings.customerToTech == null)
            FilledButton(
              onPressed: () async {
                final stars = await showRatingSheet(
                  context,
                  title: job.isOilOrder
                      ? 'قيّم ورشة الزيوت'
                      : job.isWashOrder
                          ? 'قيّم المغسل'
                          : job.isTowOrder
                              ? 'قيّم السطحة'
                              : (job.isPartsOrder
                                  ? 'قيّم الورشة'
                                  : 'قيّم الفني'),
                );
                if (stars == null || !context.mounted) return;
                await jobs.rateAsCustomer(job.id, stars);
                await jobs.markRatedIfDone(job.id);
              },
              child: Text(
                job.isOilOrder
                    ? 'تقييم ورشة الزيوت'
                    : job.isWashOrder
                        ? 'تقييم المغسل'
                        : job.isTowOrder
                            ? 'تقييم السطحة'
                            : (job.isPartsOrder
                                ? 'تقييم الورشة'
                                : 'تقييم الفني'),
              ),
            )
          else
            Text(
              job.isOilOrder
                  ? 'تم إرسال تقييمك لورشة الزيوت.'
                  : job.isWashOrder
                      ? 'تم إرسال تقييمك للمغسل.'
                      : job.isTowOrder
                          ? 'تم إرسال تقييمك للسطحة.'
                          : (job.isPartsOrder
                              ? 'تم إرسال تقييمك للورشة.'
                              : 'تم إرسال تقييمك للفني.'),
            ),
        ];
      case JobStatus.noTechnician:
        return [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amberTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 20, color: Color(0xFF92400E)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.waitingForProviderBody,
                    style: TextStyle(
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => jobs.maybeRedispatch(job.id),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.slate,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(AppStrings.retrySearchProviders),
          ),
        ];
      case JobStatus.cancelled:
        return [
          StatusPill(
            label: _cancelledByLabel(job.cancelledBy),
            color: AppColors.danger,
            background: AppColors.dangerTint,
            icon: Icons.cancel_outlined,
          ),
          if (job.cancelReason.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'السبب: ${job.cancelReason.trim()}',
              style: const TextStyle(color: AppColors.inkSoft, height: 1.4),
            ),
          ],
        ];
      case JobStatus.rated:
        return const [SizedBox.shrink()];
    }
  }

  String _cancelledByLabel(String by) {
    switch (by) {
      case 'customer':
        return 'ألغيت الطلب';
      case 'technician':
        return 'انسحب المزود';
      case 'workshop':
        return 'ألغت الورشة الطلب';
      default:
        return 'ملغى';
    }
  }

  List<Widget> _partsPreparing(JobRepository jobs) {
    return [
      _liveCard('تم قبول العرض — الورشة تجهّز القطعة وترسلها إليك'),
      const SizedBox(height: 10),
      _techLine(),
      const SizedBox(height: 8),
      _priceLine('سعر القطعة المتفق', job.billAmount > 0 ? job.billAmount : job.initialPrice),
      if (job.warranty.enabled) ...[
        const SizedBox(height: 10),
        StatusPill(
          label: warrantyLabel(job.warranty),
          icon: Icons.verified_user_outlined,
        ),
      ],
    ];
  }

  List<Widget> _partsReceive(BuildContext context, JobRepository jobs) {
    return [
      _liveCard('القطعة في الطريق إليك'),
      const SizedBox(height: 10),
      _techLine(),
      const SizedBox(height: 8),
      _priceLine('المبلغ عند الاستلام', job.billAmount > 0 ? job.billAmount : job.initialPrice),
      if (job.warranty.enabled) ...[
        const SizedBox(height: 10),
        StatusPill(
          label: warrantyLabel(job.warranty),
          icon: Icons.verified_user_outlined,
        ),
      ],
      if (job.shippedPartImageUrl.isNotEmpty) ...[
        const SizedBox(height: 12),
        FieldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'صورة القطعة المُرسلة',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: AppNetworkOrDataImage(
                    source: job.shippedPartImageUrl,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () async {
          try {
            await jobs.customerConfirmPartsReceived(job.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تأكيد استلام الطلب.')),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  userFacingError(e, prefix: 'تعذّر تأكيد الاستلام.'),
                ),
              ),
            );
          }
        },
        child: const Text('استلام الطلب'),
      ),
    ];
  }

  Future<void> _accept(
    BuildContext context,
    Future<void> Function() action,
    String prefix,
  ) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.showError(context, userFacingError(e, prefix: prefix));
    }
  }

  Widget _techLine() {
    final name = job.technicianName ??
        (job.isPartsOrder
            ? 'ورشة'
            : job.isOilOrder
                ? 'ورشة زيوت'
                : job.isWashOrder
                    ? 'مغسل'
                    : 'فني');
    final card = FieldCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.recessed,
            child: Text(name.isEmpty ? 'و' : name.substring(0, 1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (job.isPartsOrder || !job.locationRevealed) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        const SizedBox(height: 8),
        ProviderContactBlock(job: job, framed: true),
      ],
    );
  }

  Widget _priceLine(String label, double? value) {
    return Row(
      children: [
        Expanded(
            child:
                Text(label, style: const TextStyle(color: AppColors.inkSoft))),
        Text(
          value == null ? '-' : formatIqd(value),
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.emeraldDeep),
        ),
      ],
    );
  }

  Widget _liveCard(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({
    required this.status,
    this.isParts = false,
    this.isWash = false,
    this.isTow = false,
  });

  final JobStatus status;
  final bool isParts;
  final bool isWash;
  final bool isTow;

  @override
  Widget build(BuildContext context) {
    final simple = isWash || isTow;
    final labels = isParts
        ? const ['القبول', 'التجهيز', 'الإرسال', 'الاستلام']
        : isWash
            ? const ['القبول', 'في الطريق', 'الغسيل']
            : isTow
                ? const ['القبول', 'في الطريق', 'النقل']
                : const ['القبول', 'في الطريق', 'الفحص', 'العمل'];
    final active = switch (status) {
      JobStatus.providerQueued || JobStatus.quoted => 0,
      JobStatus.enRoute => 1,
      JobStatus.arrived => simple ? 2 : 2,
      JobStatus.finalQuote => simple ? 2 : 2,
      JobStatus.inProgress => simple ? 2 : 3,
      _ => simple ? 2 : 3,
    };
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 3,
                color: i <= active ? AppColors.amber : AppColors.outline,
              ),
            ),
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: i <= active ? AppColors.amber : AppColors.recessed,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  i < active ? Icons.check : Icons.circle,
                  size: i < active ? 14 : 8,
                  color: i <= active ? AppColors.ink : AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: i == active ? AppColors.ink : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

Future<String?> _askReason(BuildContext context, String title, String label) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
