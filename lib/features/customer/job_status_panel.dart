import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/customer/quote_compare_list.dart';
import 'package:barrr/features/jobs/rating_sheet.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/services/job_repository.dart';

class CustomerJobPanel extends StatelessWidget {
  const CustomerJobPanel({super.key, required this.job, required this.me});

  final Job job;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 16,
      shadowColor: AppColors.slate.withValues(alpha: 0.16),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.62),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                job.serviceTitle ?? job.serviceId,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              if (job.vehicleTypeTitle != null &&
                  job.vehicleTypeTitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'نوع السيارة: ${job.vehicleTypeTitle}',
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                ),
              ],
              if (_showSteps(job.status)) ...[
                const SizedBox(height: 14),
                _Steps(status: job.status),
              ],
              const SizedBox(height: 14),
              ..._body(context),
            ],
          ),
        ),
      ),
    );
  }

  bool _showSteps(JobStatus s) {
    return s == JobStatus.quoted ||
        s == JobStatus.enRoute ||
        s == JobStatus.arrived ||
        s == JobStatus.finalQuote ||
        s == JobStatus.inProgress;
  }

  String _title(JobStatus s) {
    switch (s) {
      case JobStatus.dispatching:
      case JobStatus.offerPending:
        return job.isEmergency
            ? AppStrings.searching
            : AppStrings.collectingQuotes;
      case JobStatus.comparing:
        return AppStrings.compareQuotes;
      case JobStatus.quoted:
        return 'فني قبل الطلب';
      case JobStatus.enRoute:
        return 'الفني في الطريق إليك';
      case JobStatus.arrived:
        return 'الفني وصل — جاري الفحص';
      case JobStatus.finalQuote:
        return 'السعر النهائي بانتظار موافقتك';
      case JobStatus.inProgress:
        return 'جاري العمل';
      case JobStatus.completed:
        return 'انتهت المهمة';
      case JobStatus.noTechnician:
        return 'لم يُعثر على فني';
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
      items.add(const SizedBox(height: 8));
      items.add(
        OutlinedButton(
          onPressed: () => _confirmCancel(context),
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
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: job.useWallet,
        title: Text('استخدم الرصيد (${formatIqd(balance)})'),
        subtitle: Text(
          job.useWallet
              ? 'يُخصم ${formatIqd(job.walletReserve)} من المطلوب نقداً'
              : 'الباقي من الدفع يبقى في المحفظة للطلب التالي',
        ),
        onChanged: (use) {
          AppScope.of(context).jobs.setUseWallet(
                jobId: job.id,
                use: use,
                reserve: use ? reserve : 0,
              );
        },
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  List<Widget> _statusBody(BuildContext context, JobRepository jobs) {
    switch (job.status) {
      case JobStatus.dispatching:
      case JobStatus.offerPending:
        if (job.isEmergency) {
          return const [
            LinearProgressIndicator(),
            SizedBox(height: 8),
            Text('نبحث عن أقرب فني مناسب. قد يستغرق القبول 30 ثانية.'),
          ];
        }
        return [
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text(
              'نافذة قصيرة لجمع عروض السعر. إن وصل عرض واحد فقط يُعيَّن تلقائياً.'),
          const SizedBox(height: 12),
          QuoteCompareList(job: job, selectable: false),
        ];
      case JobStatus.comparing:
        return [
          const Text(
              'اختر حسب السعر والتقييم والمسافة التقريبية. رقم الهاتف والموقع الكامل مخفيان.'),
          const SizedBox(height: 12),
          QuoteCompareList(job: job, selectable: true),
        ];
      case JobStatus.quoted:
        return [
          _techLine(),
          const SizedBox(height: 10),
          _priceLine('السعر المبدئي', job.initialPrice),
          const SizedBox(height: 8),
          const Text(AppStrings.cashNote,
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => jobs.customerAcceptQuote(job.id),
            child: const Text('قبول السعر وتوجيه الفني'),
          ),
        ];
      case JobStatus.enRoute:
        return [
          _liveCard('الفني في الطريق إليك', 'موقعك الحقيقي ظاهر له الآن.'),
          const SizedBox(height: 10),
          _techLine(),
          const SizedBox(height: 8),
          _priceLine('السعر المبدئي', job.initialPrice),
        ];
      case JobStatus.arrived:
        return [
          _liveCard('جاري الفحص الميداني', 'سيصلك السعر النهائي بعد التشخيص.'),
          const SizedBox(height: 10),
          _techLine(),
        ];
      case JobStatus.finalQuote:
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
                const SizedBox(height: 6),
                const Text(
                  'دفع نقدي عند انتهاء العمل',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
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
            onPressed: () => jobs.customerAcceptFinal(job.id),
            child: const Text('موافقة على السعر وبدء الصيانة'),
          ),
          ..._walletSwitch(context),
        ];
      case JobStatus.inProgress:
        return [
          _liveCard('العمل جارٍ', 'سيظهر إنهاء المهمة عند اكتماله.'),
          if (job.warranty.enabled) ...[
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
                final users = AppScope.of(context).users;
                final stars =
                    await showRatingSheet(context, title: 'قيّم الفني');
                if (stars == null || !context.mounted) return;
                await jobs.rateAsCustomer(job.id, stars);
                if (job.technicianId != null) {
                  await users.applyRating(job.technicianId!, stars);
                }
                await jobs.markRatedIfDone(job.id);
              },
              child: const Text('تقييم الفني'),
            )
          else
            const Text('تم إرسال تقييمك للفني.'),
        ];
      case JobStatus.noTechnician:
        return [
          const Text('لم يتوفر فني الآن. حاول مرة أخرى.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => jobs.maybeRedispatch(job.id),
            child: const Text('إعادة البحث'),
          ),
        ];
      default:
        return const [SizedBox.shrink()];
    }
  }

  Widget _techLine() {
    final name = job.technicianName ?? 'فني';
    return FieldCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.recessed,
            child: Text(name.isEmpty ? 'ف' : name.substring(0, 1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Text('فني معيّن للطلب',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
              ],
            ),
          ),
          const StatusPill(label: 'معتمد', icon: Icons.verified_outlined),
        ],
      ),
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

  Widget _liveCard(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 6),
          Text(body,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.status});

  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    const labels = ['القبول', 'في الطريق', 'الفحص', 'العمل'];
    final active = switch (status) {
      JobStatus.quoted => 0,
      JobStatus.enRoute => 1,
      JobStatus.arrived || JobStatus.finalQuote => 2,
      _ => 3,
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
