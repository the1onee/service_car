import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';

class QuoteCompareList extends StatelessWidget {
  const QuoteCompareList({
    super.key,
    required this.job,
    required this.selectable,
  });

  final Job job;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final oil = job.isOilOrder;
    final emptyLabel = oil
        ? 'لم تصل عروض بعد. انتظر ورش الزيوت القريبة.'
        : 'لم تصل عروض بعد. انتظر الفنيين القريبين.';
    final pickLabel = oil ? 'اختيار هذه الورشة' : 'اختيار هذا الفني';

    return StreamBuilder<List<JobOffer>>(
      stream: AppScope.of(context).jobs.watchJobQuotes(job.id),
      builder: (context, snap) {
        final quotes = snap.data ?? const <JobOffer>[];
        if (quotes.isEmpty) {
          return Text(emptyLabel);
        }
        final sorted = [...quotes]..sort((a, b) {
            // وكالات أصلية أولاً ثم الموثوقة ثم الباقي.
            int rank(JobOffer q) {
              if (q.isAgencyOilWorkshop) return 0;
              if (q.isTrustedOilWorkshop) return 1;
              return 2;
            }

            final byTier = rank(a).compareTo(rank(b));
            if (byTier != 0) return byTier;
            return (a.initialPrice ?? double.infinity)
                .compareTo(b.initialPrice ?? double.infinity);
          });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final q in sorted)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FieldCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              q.technicianName ?? (oil ? 'ورشة زيوت' : 'فني'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (oil && q.isAgencyOilWorkshop)
                            const StatusPill(
                              label: AppStrings.oilWorkshopAgency,
                              icon: Icons.verified,
                              color: AppColors.petrolDark,
                              background: AppColors.petrolTint,
                            )
                          else if (oil && q.isTrustedOilWorkshop)
                            const StatusPill(
                              label: AppStrings.oilWorkshopTrusted,
                              icon: Icons.shield_outlined,
                            )
                          else if (q.verified)
                            const StatusPill(
                              label: AppStrings.verifiedBadge,
                              icon: Icons.verified_outlined,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q.initialPrice == null
                            ? '-'
                            : formatIqd(q.initialPrice!),
                        style: const TextStyle(
                          color: AppColors.emeraldDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'التقييم ${q.ratingAvg.toStringAsFixed(1)}  ·  المسافة ${q.distanceKm == null ? '-' : '${q.distanceKm!.toStringAsFixed(1)} كم'}',
                        style: const TextStyle(
                            color: AppColors.inkSoft, fontSize: 12),
                      ),
                      if (selectable) ...[
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () =>
                              AppScope.of(context).dispatch.selectOffer(
                                    jobId: job.id,
                                    offer: q,
                                  ),
                          child: Text(pickLabel),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
