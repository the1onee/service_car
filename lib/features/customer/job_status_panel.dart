import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/customer/parts_offers_section.dart';
import 'package:barrr/features/customer/quote_compare_list.dart';
import 'package:barrr/features/customer/wash_job_details.dart';
import 'package:barrr/features/jobs/rating_sheet.dart';
import 'package:barrr/features/oil_workshop/oil_job_details.dart';
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
                job.isWashOrder
                    ? job.washDisplayTitle
                    : job.isOilOrder
                        ? job.oilDisplayTitle
                        : (job.serviceTitle ?? job.serviceId),
                style: TextStyle(
                  color: (job.isOilOrder || job.isWashOrder)
                      ? AppColors.amberDeep
                      : AppColors.inkSoft,
                  fontWeight: (job.isOilOrder || job.isWashOrder)
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              if (job.isWashOrder) ...[
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
                _Steps(status: job.status, isParts: job.isPartsOrder),
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
    if (job.isPartsOrder) {
      return s == JobStatus.quoted ||
          s == JobStatus.enRoute ||
          s == JobStatus.arrived ||
          s == JobStatus.inProgress;
    }
    return s == JobStatus.quoted ||
        s == JobStatus.enRoute ||
        s == JobStatus.arrived ||
        s == JobStatus.finalQuote ||
        s == JobStatus.inProgress;
  }

  String _title(JobStatus s) {
    final parts = job.isPartsOrder;
    final oil = job.isOilOrder;
    final wash = job.isWashOrder;
    switch (s) {
      case JobStatus.dispatching:
      case JobStatus.offerPending:
        if (wash) return 'بانتظار عروض الغسيل';
        return job.isEmergency
            ? AppStrings.searching
            : AppStrings.collectingQuotes;
      case JobStatus.comparing:
        return wash ? 'بانتظار عروض الغسيل' : AppStrings.compareQuotes;
      case JobStatus.quoted:
        if (parts) return 'الورشة تجهّز طلبك';
        if (oil) return 'ورشة الزيوت قبلت الطلب';
        if (wash) return 'مغسل قبل الطلب';
        return 'فني قبل الطلب';
      case JobStatus.enRoute:
        if (parts) return 'الورشة تجهّز القطعة';
        if (oil) return 'ورشة الزيوت في الطريق إليك';
        if (wash) return 'مغسل في الطريق';
        return 'الفني في الطريق إليك';
      case JobStatus.arrived:
        if (parts) return 'الورشة بصدد الإرسال';
        if (oil) return 'ورشة الزيوت وصلت — جاري التبديل';
        if (wash) return 'المغسل وصل — جاري الغسيل';
        return 'الفني وصل — جاري الفحص';
      case JobStatus.finalQuote:
        if (parts) return 'القطعة في الطريق إليك';
        return 'السعر النهائي بانتظار موافقتك';
      case JobStatus.inProgress:
        if (parts) return 'القطعة في الطريق — أكّد الاستلام';
        if (oil) return 'جاري تبديل الزيت';
        if (wash) return 'جاري الغسيل';
        return 'جاري العمل';
      case JobStatus.completed:
        if (parts) return 'تم استلام القطعة';
        if (oil) return 'تم تبديل الزيت';
        if (wash) return 'تم الغسيل';
        return 'انتهت المهمة';
      case JobStatus.noTechnician:
        if (parts) return 'لم تُعثر على ورشة';
        if (oil) return 'لم تُعثر على ورشة زيوت';
        if (wash) return 'لم يُعثر على مغسل';
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
          return [
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text('بانتظار القبول'),
          ];
        }
        if (job.isPartsOrder) {
          return [
            PartsOffersSection(job: job, selectable: true),
          ];
        }
        if (job.isOilOrder) {
          return [
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
            const Text(
              'اختر عرض الغسيل عندما يصل — بدون مهلة زمنية.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 12),
            QuoteCompareList(job: job, selectable: true),
          ];
        }
        if (job.isTechnicianJob) {
          return [
            const Text(
              'اختر عرض الفني عندما يصل — بدون مهلة زمنية.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 12),
            QuoteCompareList(job: job, selectable: true),
          ];
        }
        return [
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
            onPressed: () => jobs.customerAcceptQuote(job.id),
            child: Text(
              job.isOilOrder || job.isWashOrder
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
                    : 'جاري الفحص',
          ),
          const SizedBox(height: 10),
          _techLine(),
        ];
      case JobStatus.finalQuote:
        if (job.isPartsOrder) {
          return _partsReceive(context, jobs);
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
            onPressed: () => jobs.customerAcceptFinal(job.id),
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
                    : 'العمل جارٍ',
          ),
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
                final stars = await showRatingSheet(
                  context,
                  title: job.isOilOrder
                      ? 'قيّم ورشة الزيوت'
                      : job.isWashOrder
                          ? 'قيّم المغسل'
                          : (job.isPartsOrder ? 'قيّم الورشة' : 'قيّم الفني'),
                );
                if (stars == null || !context.mounted) return;
                await jobs.rateAsCustomer(job.id, stars);
                if (job.technicianId != null) {
                  await users.applyRating(job.technicianId!, stars);
                }
                await jobs.markRatedIfDone(job.id);
              },
              child: Text(
                job.isOilOrder
                    ? 'تقييم ورشة الزيوت'
                    : job.isWashOrder
                        ? 'تقييم المغسل'
                        : (job.isPartsOrder ? 'تقييم الورشة' : 'تقييم الفني'),
              ),
            )
          else
            Text(
              job.isOilOrder
                  ? 'تم إرسال تقييمك لورشة الزيوت.'
                  : job.isWashOrder
                      ? 'تم إرسال تقييمك للمغسل.'
                      : (job.isPartsOrder
                          ? 'تم إرسال تقييمك للورشة.'
                          : 'تم إرسال تقييمك للفني.'),
            ),
        ];
      case JobStatus.noTechnician:
        return [
          Text(
            job.isOilOrder
                ? 'لم تتوفر ورشة زيوت الآن. حاول مرة أخرى.'
                : job.isWashOrder
                    ? 'لم يتوفر مغسل الآن. حاول مرة أخرى.'
                    : (job.isPartsOrder
                        ? 'لم تتوفر ورشة الآن. حاول مرة أخرى.'
                        : 'لم يتوفر فني الآن. حاول مرة أخرى.'),
          ),
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
              SnackBar(content: Text('تعذّر تأكيد الاستلام: $e')),
            );
          }
        },
        child: const Text('استلام الطلب'),
      ),
    ];
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
    return FieldCard(
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
  const _Steps({required this.status, this.isParts = false});

  final JobStatus status;
  final bool isParts;

  @override
  Widget build(BuildContext context) {
    final labels = isParts
        ? const ['القبول', 'التجهيز', 'الإرسال', 'الاستلام']
        : const ['القبول', 'في الطريق', 'الفحص', 'العمل'];
    final active = switch (status) {
      JobStatus.quoted => 0,
      JobStatus.enRoute => 1,
      JobStatus.arrived => isParts ? 2 : 2,
      JobStatus.finalQuote => isParts ? 2 : 2,
      JobStatus.inProgress => 3,
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
