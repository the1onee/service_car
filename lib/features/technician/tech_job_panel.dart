import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/rating_sheet.dart';
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
    if (oldWidget.job.id != widget.job.id) _seedReceived(widget.job);
  }

  void _seedReceived(Job job) {
    if (_received.text.trim().isNotEmpty) return;
    final price = job.finalPrice ?? job.initialPrice;
    if (price != null && price > 0) {
      _received.text = price.toStringAsFixed(0);
    }
  }

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
              if (job.locationRevealed)
                Text(
                  'موقع العميل: ${job.displayLocation.latitude.toStringAsFixed(5)}, ${job.displayLocation.longitude.toStringAsFixed(5)}',
                ),
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
            decoration: const InputDecoration(labelText: AppStrings.finalPrice),
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
              final p = double.tryParse(_finalPrice.text);
              if (p == null) return;
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
        return [
          const Text(AppStrings.cashNote),
          const SizedBox(height: 8),
          TextField(
            controller: _received,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: AppStrings.receivedAmount,
              hintText: 'مثال: 25000',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    final p = _parseMoney(_received.text);
                    if (p == null || p <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'أدخل المبلغ المستلم بالأرقام، مثل 25000')),
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
