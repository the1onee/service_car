import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/rating_sheet.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/warranty.dart';

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
              Text(_title(job.status),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(job.serviceTitle ?? ''),
              if (job.vehicleTypeTitle != null &&
                  job.vehicleTypeTitle!.trim().isNotEmpty)
                Text('نوع السيارة: ${job.vehicleTypeTitle}'),
              if (job.status == JobStatus.quoted)
                const Text(
                    'بانتظار قبول العميل للسعر المبدئي. الموقع الحقيقي مخفي.'),
              if (job.locationRevealed) ...[
                Text(
                  'موقع العميل: ${job.displayLocation.latitude.toStringAsFixed(5)}, ${job.displayLocation.longitude.toStringAsFixed(5)}',
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => openCustomerInMaps(
                    job.displayLocation.latitude,
                    job.displayLocation.longitude,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('فتح في خرائط Google'),
                ),
              ],
              const SizedBox(height: 12),
              ..._actions(context, job),
            ],
          ),
        ),
      ),
    );
  }

  String _title(JobStatus s) {
    switch (s) {
      case JobStatus.quoted:
        return 'تم قبولك — انتظر موافقة العميل';
      case JobStatus.enRoute:
        return 'توجه إلى العميل';
      case JobStatus.arrived:
        return 'افحص السيارة وحدد السعر النهائي';
      case JobStatus.finalQuote:
        return 'بانتظار موافقة العميل على السعر النهائي';
      case JobStatus.inProgress:
        return 'يمكنك إنهاء المهمة بعد العمل';
      case JobStatus.completed:
        return 'قيّم العميل';
      default:
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
      case JobStatus.enRoute:
        return [
          FilledButton(
            onPressed: () => jobs.markArrived(job.id),
            child: const Text(AppStrings.arrived),
          ),
        ];
      case JobStatus.arrived:
        return [
          TextField(
            controller: _finalPrice,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: AppStrings.finalPrice,
              hintText: '5000',
              helperText: 'الحد الأدنى 3000 وينتهي بـ 000',
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
              if (amountError != null || parsed == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      amountError ?? 'أدخل مبلغاً ينتهي بـ 000، والحد الأدنى 3000',
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
      case JobStatus.inProgress:
        final due = job.cashDue > 0 ? job.cashDue : job.billAmount;
        return [
          const Text(AppStrings.cashNote),
          const SizedBox(height: 8),
          if (job.billAmount > 0)
            Text('الفاتورة ${formatIqd(job.billAmount)}'),
          if (job.useWallet && job.walletReserve > 0)
            Text('يُخصم ${formatIqd(job.walletReserve)} من محفظة العميل'),
          if (due > 0) Text('المطلوب نقداً ${formatIqd(due)}'),
          const SizedBox(height: 8),
          TextField(
            controller: _received,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: AppStrings.receivedAmount,
              hintText: '25000',
              helperText: 'الحد الأدنى 3000 وينتهي بـ 000',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    final parsed = _parseMoney(_received.text);
                    final due = job.cashDue > 0 ? job.cashDue : job.billAmount;
                    final p = parsed ?? (due <= 0 ? 0.0 : null);
                    final amountError =
                        (p == 0 && due <= 0) ? null : AppConstants.serviceAmountError(p);
                    if (amountError != null || p == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            amountError ?? 'أدخل مبلغاً ينتهي بـ 000، والحد الأدنى 3000',
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
                        warrantyEnabled: job.warranty.enabled,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'تعذّر إنهاء المهمة: ${_readableError(e)}')),
                      );
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(_busy ? 'جارٍ الإنهاء…' : AppStrings.endJob),
          ),
        ];
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
}

String _readableError(Object e) {
  final dynamic err = e;
  try {
    final inner = err.error;
    if (inner != null) {
      final dynamic boxed = inner;
      final message = boxed.message ?? boxed.code;
      if (message != null) return '$message';
      return '$inner';
    }
  } catch (_) {}
  return '$e';
}

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

Future<void> openCustomerInMaps(double lat, double lng) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened) return;
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}
