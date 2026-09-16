import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/features/customer/quote_compare_list.dart';
import 'package:barrr/features/jobs/rating_sheet.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';

class CustomerJobPanel extends StatelessWidget {
  const CustomerJobPanel({super.key, required this.job, required this.me});

  final Job job;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_title(job.status), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(job.serviceTitle ?? job.serviceId),
            const SizedBox(height: 12),
            ..._body(context),
          ],
        ),
        ),
      ),
    );
  }

  String _title(JobStatus s) {
    switch (s) {
      case JobStatus.dispatching:
      case JobStatus.offerPending:
        return job.isEmergency ? AppStrings.searching : AppStrings.collectingQuotes;
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
          const Text('نافذة قصيرة لجمع عروض السعر. إن وصل عرض واحد فقط يُعيَّن تلقائياً.'),
          const SizedBox(height: 12),
          QuoteCompareList(job: job, selectable: false),
        ];
      case JobStatus.comparing:
        return [
          const Text('اختر حسب السعر والتقييم والمسافة التقريبية. رقم الهاتف والموقع الكامل مخفيان.'),
          const SizedBox(height: 12),
          QuoteCompareList(job: job, selectable: true),
        ];
      case JobStatus.quoted:
        return [
          Text('الفني: ${job.technicianName ?? 'فني'}'),
          Text('السعر المبدئي: ${job.initialPrice?.toStringAsFixed(0) ?? '-'}'),
          const SizedBox(height: 8),
          const Text(AppStrings.cashNote),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => jobs.customerAcceptQuote(job.id),
            child: const Text('قبول السعر وتوجيه الفني'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => jobs.customerRejectQuote(job.id),
            child: const Text(AppStrings.reject),
          ),
        ];
      case JobStatus.enRoute:
        return [
          Text('الفني ${job.technicianName ?? ''} في الطريق. موقعك الحقيقي ظاهر له الآن.'),
        ];
      case JobStatus.arrived:
        return const [Text('الفني يفحص السيارة وسيحدد السعر النهائي.')];
      case JobStatus.finalQuote:
        return [
          Text('السعر النهائي: ${job.finalPrice?.toStringAsFixed(0) ?? '-'}'),
          Text(warrantyLabel(job.warranty)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => jobs.customerAcceptFinal(job.id),
            child: const Text('الموافقة على السعر النهائي'),
          ),
        ];
      case JobStatus.inProgress:
        return const [Text('العمل جارٍ. سيظهر إنهاء المهمة عند اكتماله.')];
      case JobStatus.completed:
        return [
          Text('المبلغ المستلم: ${job.receivedAmount?.toStringAsFixed(0) ?? '-'}'),
          Text(warrantyLabel(job.warranty)),
          const SizedBox(height: 8),
          if (job.ratings.customerToTech == null)
            FilledButton(
              onPressed: () async {
                final stars = await showRatingSheet(context, title: 'قيّم الفني');
                if (stars == null) return;
                await jobs.rateAsCustomer(job.id, stars);
                await AppScope.of(context).users.applyRating(job.technicianId!, stars);
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
          FilledButton(
            onPressed: () => jobs.maybeRedispatch(job.id),
            child: const Text('إعادة البحث'),
          ),
        ];
      default:
        return const [SizedBox.shrink()];
    }
  }
}
