import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
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
    return StreamBuilder<List<JobOffer>>(
      stream: AppScope.of(context).jobs.watchJobQuotes(job.id),
      builder: (context, snap) {
        final quotes = snap.data ?? const <JobOffer>[];
        if (quotes.isEmpty) {
          return const Text('لم تصل عروض بعد. انتظر الفنيين القريبين.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final q in quotes)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              q.technicianName ?? 'فني',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (q.verified)
                            const Chip(
                              label: Text(AppStrings.verifiedBadge),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('السعر المبدئي: ${q.initialPrice?.toStringAsFixed(0) ?? '-'} د.ع'),
                      Text('التقييم: ${q.ratingAvg.toStringAsFixed(1)}'),
                      Text(
                        'المسافة التقريبية: ${q.distanceKm == null ? '-' : '${q.distanceKm!.toStringAsFixed(1)} كم'}',
                      ),
                      if (selectable) ...[
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => AppScope.of(context).dispatch.selectOffer(
                                jobId: job.id,
                                offer: q,
                              ),
                          child: const Text('اختيار هذا الفني'),
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
