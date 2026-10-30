import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/app_sound.dart';
import 'package:barrr/core/app_svg_icons.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';

/// قسم عروض الورش لطلب قطع الغيار — مطابق لتصميم بطاقات العروض.
class PartsOffersSection extends StatelessWidget {
  const PartsOffersSection({
    super.key,
    required this.job,
    this.onAccepted,
    this.selectable,
  });

  final Job job;
  final VoidCallback? onAccepted;
  /// إن null: يُفعَّل الاختيار تلقائياً عند حالة comparing.
  final bool? selectable;

  static const _secondary = Color(0xFF855300);

  bool get _canSelect =>
      selectable ??
      (job.status == JobStatus.comparing || job.status == JobStatus.offerPending);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<List<JobOffer>>(
      stream: AppScope.of(context).jobs.watchJobQuotes(job.id),
      builder: (context, snap) {
        final quotes = (snap.data ?? const <JobOffer>[])
            .where(
              (q) =>
                  q.status == OfferStatus.submitted ||
                  q.status == OfferStatus.accepted ||
                  (q.initialPrice != null && q.initialPrice! > 0),
            )
            .toList();
        quotes.sort((a, b) {
          final pa = a.initialPrice ?? 1e12;
          final pb = b.initialPrice ?? 1e12;
          return pa.compareTo(pb);
        });

        JobOffer? bestRated;
        for (final q in quotes) {
          if (bestRated == null || q.ratingAvg > bestRated.ratingAvg) {
            bestRated = q;
          }
        }

        final waiting = job.status == JobStatus.dispatching ||
            job.status == JobStatus.offerPending;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_outlined,
                    color: _secondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'العروض',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  quotes.isEmpty
                      ? (waiting ? 'جارٍ الجمع…' : 'لا عروض')
                      : '${quotes.length} عرض',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (quotes.isEmpty && waiting) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 12),
              Text('بانتظار العروض', style: textTheme.bodyMedium),
            ] else if (quotes.isEmpty)
              Text('بانتظار العروض', style: textTheme.bodyMedium)
            else
              for (final q in quotes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OfferCard(
                    offer: q,
                    isAgency: quotes.length == 1 || q.id == bestRated?.id,
                    canSelect: _canSelect &&
                        job.status != JobStatus.quoted &&
                        job.status != JobStatus.enRoute &&
                        job.status != JobStatus.inProgress &&
                        job.status != JobStatus.completed,
                    onAccept: () async {
                      AppSoundService.playAcceptClient();
                      await AppScope.of(context).dispatch.selectOffer(
                            jobId: job.id,
                            offer: q,
                          );
                      onAccepted?.call();
                    },
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.isAgency,
    required this.canSelect,
    required this.onAccept,
  });

  final JobOffer offer;
  final bool isAgency;
  final bool canSelect;
  final VoidCallback onAccept;

  static const _secondary = Color(0xFF855300);
  static const _secondaryContainer = Color(0xFFFEA619);
  static const _surfaceHigh = Color(0xFFDCE9FF);

  String get _conditionShort {
    return switch (offer.partCondition) {
      'oem' => 'أصلي',
      'aftermarket' => 'تجاري',
      'used' => 'مستعمل',
      _ => offer.partCondition,
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final meta = <String>[
      if (_conditionShort.isNotEmpty) _conditionShort,
      if (offer.warrantyDays > 0) 'ضمان ${offer.warrantyDays}ي',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isAgency
            ? Border.all(color: Colors.black.withValues(alpha: 0.14))
            : Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppSvgIcons.workshop(size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offer.technicianName ?? 'ورشة',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.star_rounded,
                  size: 14, color: _secondaryContainer),
              const SizedBox(width: 2),
              Text(
                offer.ratingAvg.toStringAsFixed(1),
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  meta.isEmpty ? 'حسب عرض الورشة' : meta,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                offer.initialPrice == null
                    ? '—'
                    : formatIqd(offer.initialPrice!),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isAgency ? _secondary : AppColors.ink,
                ),
              ),
            ],
          ),
          if (canSelect) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: isAgency ? Colors.black : _surfaceHigh,
                  foregroundColor: isAgency ? Colors.white : AppColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'قبول',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
