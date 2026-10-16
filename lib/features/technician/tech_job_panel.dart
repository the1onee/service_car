import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/app_snackbar.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/core/user_error.dart';
import 'package:barrr/features/customer/tow_job_details.dart';
import 'package:barrr/features/customer/wash_job_details.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/jobs/rating_sheet.dart';
import 'package:barrr/features/oil_workshop/oil_job_details.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/technician/tech_job_details.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/warranty.dart';
import 'package:barrr/services/job_repository.dart';

class TechJobPanel extends StatefulWidget {
  const TechJobPanel({super.key, required this.job, required this.me});

  final Job job;
  final AppUser me;

  @override
  State<TechJobPanel> createState() => _TechJobPanelState();
}

class _TechJobPanelState extends State<TechJobPanel> {
  final _finalPrice = TextEditingController();
  final _received = TextEditingController();
  bool _warranty = false;
  WarrantyType _wType = WarrantyType.work;
  String _wNote = '';
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _seedReceived(widget.job);
  }

  @override
  void didUpdateWidget(TechJobPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.job.id != widget.job.id) {
      _received.text = '';
      _seedReceived(widget.job);
      return;
    }
    final oldDue = _dueOf(oldWidget.job);
    final nextDue = _dueOf(widget.job);
    if (_received.text.trim() == oldDue.toStringAsFixed(0) && oldDue != nextDue) {
      _received.text = nextDue > 0 ? nextDue.toStringAsFixed(0) : '';
    }
  }

  void _seedReceived(Job job) {
    if (_received.text.trim().isNotEmpty) return;
    final due = _dueOf(job);
    if (due > 0) _received.text = due.toStringAsFixed(0);
  }

  double _dueOf(Job job) => job.cashDue > 0 ? job.cashDue : job.billAmount;

  @override
  void dispose() {
    _finalPrice.dispose();
    _received.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final oil = job.isOilOrder;
    final wash = job.isWashOrder;
    final tow = job.isTowOrder;
    return Material(
      color: AppColors.surface,
      elevation: 16,
      shadowColor: AppColors.slate.withValues(alpha: 0.16),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_title(job.status, oil: oil, wash: wash, tow: tow),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                tow
                    ? (job.serviceTitle ?? 'سطحة')
                    : wash
                        ? job.washDisplayTitle
                        : (oil
                            ? job.oilDisplayTitle
                            : (job.serviceTitle ?? '')),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: (oil || wash || tow)
                      ? AppColors.amberDeep
                      : AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              if (job.locationRevealed) ...[
                CustomerContactBlock(job: job),
                const SizedBox(height: 10),
              ],
              if (tow)
                TowJobDetailsCard.fromJob(
                  job,
                  compact: true,
                  showPhone: false,
                )
              else if (wash)
                WashJobDetailsCard.fromJob(
                  job,
                  compact: true,
                  showPhone: false,
                )
              else if (oil)
                OilJobDetailsCard.fromJob(
                  job,
                  compact: true,
                  showPhone: false,
                )
              else
                TechJobDetailsCard.fromJob(
                  job,
                  compact: true,
                  showPhone: false,
                ),
              if (job.status == JobStatus.quoted)
                Text(
                  oil
                      ? 'بانتظار قبول العميل لعرض السعر. موقع الزيارة مخفي.'
                      : wash
                          ? 'بانتظار قبول العميل لعرض الغسيل. الموقع الحقيقي مخفي.'
                          : tow
                              ? 'بانتظار قبول العميل. مواقع التحميل والتنزيل تظهر بعد القبول.'
                              : 'بانتظار قبول العميل للسعر. الموقع الحقيقي مخفي.',
                ),
              if (job.locationRevealed) ...[
                const SizedBox(height: 8),
                Text(
                  tow
                      ? 'موقع التحميل: ${job.displayLocation.latitude.toStringAsFixed(5)}, ${job.displayLocation.longitude.toStringAsFixed(5)}'
                      : 'موقع العميل: ${job.displayLocation.latitude.toStringAsFixed(5)}, ${job.displayLocation.longitude.toStringAsFixed(5)}',
                ),
                if (tow && job.dropoffLabel.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('موقع التنزيل: ${job.dropoffLabel}'),
                ],
                if (tow && job.dropoffLocation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'إحداثيات التنزيل: ${job.dropoffLocation!.latitude.toStringAsFixed(5)}, ${job.dropoffLocation!.longitude.toStringAsFixed(5)}',
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => openCustomerInMaps(
                    job.displayLocation.latitude,
                    job.displayLocation.longitude,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    tow ? 'فتح موقع التحميل في الخرائط' : 'فتح في خرائط Google',
                  ),
                ),
                if (tow && job.dropoffLocation != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => openCustomerInMaps(
                      job.dropoffLocation!.latitude,
                      job.dropoffLocation!.longitude,
                    ),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('فتح موقع التنزيل في الخرائط'),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              ..._actions(context, job),
            ],
          ),
        ),
      ),
    );
  }

  String _title(
    JobStatus s, {
    required bool oil,
    required bool wash,
    required bool tow,
  }) {
    switch (s) {
      case JobStatus.quoted:
        return oil || wash || tow
            ? 'تم قبول عرضك — انتظر موافقة العميل'
            : 'تم قبولك — انتظر موافقة العميل';
      case JobStatus.providerQueued:
        return 'طلب بانتظار بدء التنفيذ';
      case JobStatus.enRoute:
        if (oil) return 'ورشة الزيوت في الطريق';
        if (wash) return 'مغسل في الطريق';
        if (tow) return 'سطحة في الطريق للتحميل';
        return 'توجه إلى العميل';
      case JobStatus.arrived:
        if (oil) return 'وصلت — أكمل تبديل الزيت واستلم المبلغ';
        if (wash) return 'وصلت — جاري الغسيل';
        if (tow) return 'وصلت للتحميل — جاري النقل';
        return 'افحص السيارة وحدد السعر النهائي';
      case JobStatus.finalQuote:
        if (oil) return 'أكمل تبديل الزيت ثم أكّد استلام المبلغ';
        if (wash) return 'أكمل الغسيل ثم أكّد استلام المبلغ';
        if (tow) return 'أكمل النقل ثم أكّد استلام المبلغ';
        return 'بانتظار موافقة العميل على السعر النهائي';
      case JobStatus.inProgress:
        if (oil) return 'أكمل تبديل الزيت ثم أكّد استلام المبلغ';
        if (wash) return 'أكمل الغسيل ثم أكّد استلام المبلغ';
        if (tow) return 'أكمل النقل ثم أكّد استلام المبلغ';
        return 'يمكنك إنهاء المهمة بعد العمل';
      case JobStatus.completed:
        return 'قيّم العميل';
      default:
        if (oil) return 'طلب زيت جارٍ';
        if (wash) return 'طلب غسيل جارٍ';
        if (tow) return 'طلب سطحة جارٍ';
        return 'مهمة جارية';
    }
  }

  List<Widget> _actions(BuildContext context, Job job) {
    final items = List<Widget>.of(_statusActions(context, job));
    if (job.technicianCanWithdraw) {
      items.add(const SizedBox(height: 8));
      items.add(
        OutlinedButton(
          onPressed: _busy ? null : () => _withdraw(context, job),
          child: const Text(AppStrings.withdrawSearch),
        ),
      );
    }
    return items;
  }

  Future<void> _startQueued(BuildContext context, Job job) async {
    setState(() => _busy = true);
    try {
      await AppScope.of(context).jobs.startQueuedJob(job.id);
      if (!context.mounted) return;
      AppSnackBar.showSuccess(context, 'بدأت هذا الطلب');
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.showError(context, userFacingError(e, prefix: 'تعذّر بدء الطلب.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(BuildContext context, Job job) async {
    final reason = await _askReason(
      context,
      'الانسحاب من الطلب',
      'سبب الانسحاب (اختياري)',
    );
    if (reason == null || !context.mounted) return;
    setState(() => _busy = true);
    try {
      final scope = AppScope.of(context);
      await scope.jobs.technicianWithdraw(job.id, reason: reason);
      await scope.dispatch.dispatch(job.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الانسحاب: ${_readableError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _statusActions(BuildContext context, Job job) {
    final jobs = AppScope.of(context).jobs;
    switch (job.status) {
      case JobStatus.providerQueued:
        return [
          const Text(
            'العميل بانتظارك. ابدأ هذا الطلب عندما تنهي الطلب الجاري.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _startQueued(context, job),
            child: Text(_busy ? 'جارٍ البدء…' : 'ابدأ هذا الطلب'),
          ),
        ];
      case JobStatus.enRoute:
        return [
          FilledButton(
            onPressed: () => jobs.markArrived(job.id),
            child: Text(
              job.isOilOrder || job.isWashOrder
                  ? 'وصلت لموقع العميل'
                  : job.isTowOrder
                      ? 'وصلت لموقع التحميل'
                      : AppStrings.arrived,
            ),
          ),
        ];
      case JobStatus.arrived:
        // غسيل / سطحة / زيت: بلا سعر نهائي/ضمان — فقط استلام المبلغ.
        if (job.isWashOrder || job.isTowOrder || job.isOilOrder) {
          return _cashCompleteActions(context, job, jobs);
        }
        return [
          TextField(
            controller: _finalPrice,
            keyboardType: TextInputType.number,
            inputFormatters: const [IqdThousandsFormatter()],
            decoration: const InputDecoration(
              labelText: AppStrings.finalPrice,
              hintText: '5,000',
              helperText: 'الحد الأدنى 3,000 وينتهي بـ 000',
            ),
          ),
          const SizedBox(height: 8),
          WarrantyForm(
            enabled: _warranty,
            type: _wType,
            note: _wNote,
            onEnabled: (v) => setState(() => _warranty = v),
            onType: (v) => setState(() => _wType = v),
            onNote: (v) => _wNote = v,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final parsed = _parseMoney(_finalPrice.text);
              final amountError = AppConstants.serviceAmountError(parsed);
              final reductionError =
                  AppConstants.priceReductionError(parsed, job.initialPrice);
              if (amountError != null ||
                  reductionError != null ||
                  parsed == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      amountError ??
                          reductionError ??
                          'أدخل مبلغاً ينتهي بـ 000، والحد الأدنى 3000',
                    ),
                  ),
                );
                return;
              }
              final p = parsed;
              jobs.submitFinalQuote(
                jobId: job.id,
                finalPrice: p,
                warranty: Warranty(
                  enabled: _warranty,
                  type: _wType,
                  days: 2,
                  note: _wNote.isEmpty ? null : _wNote,
                ),
              );
            },
            child: const Text('إرسال السعر النهائي'),
          ),
        ];
      case JobStatus.finalQuote:
        if (job.isWashOrder || job.isTowOrder || job.isOilOrder) {
          return _cashCompleteActions(context, job, jobs);
        }
        return const [SizedBox.shrink()];
      case JobStatus.inProgress:
        return _cashCompleteActions(context, job, jobs);
      case JobStatus.completed:
        return [
          if (job.ratings.techToCustomer == null)
            FilledButton(
              onPressed: () async {
                final users = AppScope.of(context).users;
                final stars =
                    await showRatingSheet(context, title: 'قيّم العميل');
                if (stars == null || !context.mounted) return;
                await jobs.rateAsTechnician(job.id, stars);
                await users.applyRating(job.customerId, stars);
                await jobs.markRatedIfDone(job.id);
              },
              child: const Text('تقييم العميل'),
            )
          else
            const Text('تم إرسال تقييمك.'),
        ];
      default:
        return const [SizedBox.shrink()];
    }
  }

  List<Widget> _cashCompleteActions(
    BuildContext context,
    Job job,
    JobRepository jobs,
  ) {
    final due = job.cashDue > 0 ? job.cashDue : job.billAmount;
    return [
      Text(
        job.isOilOrder
            ? 'بعد إكمال تبديل الزيت أكّد المبلغ المستلم نقداً.'
            : job.isWashOrder
                ? 'بعد إكمال الغسيل أكّد المبلغ المستلم نقداً.'
                : job.isTowOrder
                    ? 'بعد إكمال النقل أكّد المبلغ المستلم نقداً.'
                    : AppStrings.cashNote,
      ),
      const SizedBox(height: 8),
      if (job.billAmount > 0) Text('الفاتورة ${formatIqd(job.billAmount)}'),
      if (job.useWallet && job.walletReserve > 0)
        Text('يُخصم ${formatIqd(job.walletReserve)} من محفظة العميل'),
      if (due > 0) Text('المطلوب نقداً ${formatIqd(due)}'),
      const SizedBox(height: 8),
      TextField(
        controller: _received,
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
        textDirection: TextDirection.ltr,
        inputFormatters: const [IqdThousandsFormatter()],
        decoration: const InputDecoration(
          labelText: AppStrings.receivedAmount,
          hintText: '25,000',
          helperText: 'الحد الأدنى 3,000 وينتهي بـ 000',
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _busy
            ? null
            : () async {
                final parsed = _parseMoney(_received.text);
                final dueNow = job.cashDue > 0 ? job.cashDue : job.billAmount;
                final p = parsed ?? (dueNow <= 0 ? 0.0 : null);
                final amountError = (p == 0 && dueNow <= 0)
                    ? null
                    : AppConstants.serviceAmountError(p);
                final reductionError = (p == null || (p == 0 && dueNow <= 0))
                    ? null
                    : _receivedReductionError(p, job, dueNow);
                if (amountError != null ||
                    reductionError != null ||
                    p == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        amountError ??
                            reductionError ??
                            'أدخل مبلغاً ينتهي بـ 000، والحد الأدنى 3000',
                      ),
                    ),
                  );
                  return;
                }
                setState(() => _busy = true);
                try {
                  await jobs.completeJob(
                    jobId: job.id,
                    receivedAmount: p,
                    warrantyEnabled: (job.isWashOrder ||
                            job.isTowOrder ||
                            job.isOilOrder)
                        ? false
                        : job.warranty.enabled,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('تعذّر إنهاء المهمة: ${_readableError(e)}'),
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        child: Text(
          _busy
              ? 'جارٍ الإنهاء…'
              : (job.isOilOrder
                  ? 'تأكيد استلام المبلغ وإكمال تبديل الزيت'
                  : job.isWashOrder
                      ? 'تأكيد استلام المبلغ وإكمال الغسيل'
                      : job.isTowOrder
                          ? 'تأكيد استلام المبلغ وإنهاء السطحة'
                          : AppStrings.endJob),
        ),
      ),
    ];
  }
}

/// عند استخدام المحفظة قد يكون المطلوب نقداً أقل من حد 20% — عندها نسمح بالمطلوب فقط.
String? _receivedReductionError(double received, Job job, double cashDue) {
  final baseline = job.initialPrice ??
      (job.billAmount > 0 ? job.billAmount : null);
  final minAllowed = AppConstants.minAllowedPriceFromBaseline(baseline);
  if (minAllowed == null) return null;
  if (job.useWallet && cashDue + 0.01 < minAllowed) {
    if (received + 0.01 < cashDue) {
      return 'المبلغ المستلم أقل من المطلوب نقداً (${cashDue.toStringAsFixed(0)})';
    }
    return null;
  }
  return AppConstants.priceReductionError(received, baseline);
}

String _readableError(Object e) => userFacingError(e);

double? _parseMoney(String raw) {
  var s = raw.trim();
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const latin = '0123456789';
  for (var i = 0; i < arabic.length; i++) {
    s = s.replaceAll(arabic[i], latin[i]);
  }
  s = s
      .replaceAll(',', '')
      .replaceAll('٬', '')
      .replaceAll(' ', '')
      .replaceAll('٫', '.');
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// الطلب الجاري أسفل الخريطة، وفوقه الطلبات التي قبلها العملاء وبانتظار البدء.
class ProviderVisitDock extends StatelessWidget {
  const ProviderVisitDock({
    super.key,
    required this.providerId,
    required this.activeJob,
    required this.panelBuilder,
    required this.idlePanel,
  });

  final String providerId;
  final Job? activeJob;
  final Widget Function(Job job) panelBuilder;
  final Widget idlePanel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Job>>(
      stream: AppScope.of(context).jobs.watchProviderQueue(providerId),
      builder: (context, snap) {
        final queued = (snap.data ?? const <Job>[])
            .where((job) => job.id != activeJob?.id)
            .toList();
        final canStart = !jobBlocksIncomingOffers(activeJob);
        final maxDock = MediaQuery.sizeOf(context).height * 0.62;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDock),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (queued.isNotEmpty)
                Flexible(
                  fit: FlexFit.loose,
                  child: _ProviderQueueStrip(jobs: queued, canStart: canStart),
                ),
              if (activeJob != null)
                Flexible(
                  fit: FlexFit.loose,
                  child: panelBuilder(activeJob!),
                )
              else if (queued.isEmpty)
                idlePanel,
            ],
          ),
        );
      },
    );
  }
}

class _ProviderQueueStrip extends StatelessWidget {
  const _ProviderQueueStrip({required this.jobs, required this.canStart});

  final List<Job> jobs;
  final bool canStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: AppColors.amberTint,
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 168),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            children: [
              Text(
                jobs.length == 1
                    ? 'طلب بانتظار بدء التنفيذ'
                    : '${jobs.length} طلبات بانتظار بدء التنفيذ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                canStart
                    ? 'اختر الطلب الذي ستبدأه. العميل الآخر يبقى بانتظارك.'
                    : 'بعد إنهاء الطلب الحالي يظهر الطلب المنتظر ويمكنك بدءه.',
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
              for (final job in jobs) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.serviceTitle ?? job.serviceId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (canStart)
                      FilledButton(
                        onPressed: () async {
                          try {
                            await AppScope.of(context).jobs.startQueuedJob(job.id);
                            if (!context.mounted) return;
                            AppSnackBar.showSuccess(context, 'بدأت هذا الطلب');
                          } catch (e) {
                            if (!context.mounted) return;
                            AppSnackBar.showError(
                              context,
                              userFacingError(e, prefix: 'تعذّر بدء الطلب.'),
                            );
                          }
                        },
                        child: const Text('ابدأ'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
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
