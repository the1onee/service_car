import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
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
  static const _surfaceLow = Color(0xFFEFF4FF);
  static const _surfaceHigh = Color(0xFFDCE9FF);

  bool get _canSelect =>
      selectable ??
      (job.status == JobStatus.comparing || job.status == JobStatus.offerPending);

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.local_offer_outlined, color: _secondary, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'عروض أسعار الورش المتاحة لطلبك',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _surfaceHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    quotes.isEmpty
                        ? (waiting ? 'جارٍ الجمع…' : 'لا عروض')
                        : '${quotes.length} عرض متاح',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF45464D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (quotes.isEmpty && waiting) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 10),
              const Text(
                'ننتظر عروض الورش القريبة. ستظهر هنا فور وصولها.',
                style: TextStyle(color: Color(0xFF45464D), height: 1.45),
              ),
            ] else if (quotes.isEmpty)
              const Text(
                'لم تصل عروض بعد من الورش.',
                style: TextStyle(color: Color(0xFF45464D)),
              )
            else
              for (final q in quotes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OfferCard(
                    offer: q,
                    isAgency: quotes.length == 1 ||
                        q.id == bestRated?.id,
                    canSelect: _canSelect &&
                        job.status != JobStatus.quoted &&
                        job.status != JobStatus.enRoute &&
                        job.status != JobStatus.inProgress &&
                        job.status != JobStatus.completed,
                    onAccept: () async {
                      await AppScope.of(context).dispatch.selectOffer(
                            jobId: job.id,
                            offer: q,
                          );
                      onAccepted?.call();
                    },
                  ),
                ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: _secondary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'الورشة المقبولة ستتولى تجهيز وتوصيل القطعة مباشرة إلى موقعك، والدفع كاش عند الاستلام والفحص.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF45464D),
                      ),
                    ),
                  ),
                ],
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
  static const _onSecondaryContainer = Color(0xFF684000);
  static const _surfaceLow = Color(0xFFEFF4FF);
  static const _surfaceHigh = Color(0xFFDCE9FF);

  @override
  Widget build(BuildContext context) {
    final badgeLabel = isAgency ? 'أفضل خيار وكالة' : 'سعر اقتصادي';
    final badgeIcon = isAgency ? Icons.verified : Icons.sell_outlined;
    final km = offer.distanceKm;
    final etaMin = km == null ? null : (12 + km * 2.2).clamp(20, 90).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isAgency
            ? Border.all(color: Colors.black.withValues(alpha: 0.18), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAgency
                      ? _secondaryContainer
                      : const Color(0xFFE5EEFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      badgeIcon,
                      size: 14,
                      color: isAgency
                          ? _onSecondaryContainer
                          : const Color(0xFF45464D),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isAgency
                            ? _onSecondaryContainer
                            : const Color(0xFF45464D),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: _secondaryContainer),
                  const SizedBox(width: 2),
                  Text(
                    offer.ratingAvg.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: _secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            offer.technicianName ?? 'ورشة',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isAgency ? Icons.schedule : Icons.local_shipping_outlined,
                size: 16,
                color: const Color(0xFF45464D),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  etaMin == null
                      ? (isAgency
                          ? 'شامل التوصيل السريع لموقعك'
                          : 'يشمل توصيل مباشر لموقعك')
                      : (isAgency
                          ? 'شامل التوصيل السريع لموقعك خلال $etaMin دقيقة'
                          : 'أجور التوصيل حسب المسافة · ~$etaMin د'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF45464D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surfaceLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المواصفات والضمان',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF45464D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (offer.partCondition.isNotEmpty)
                            switch (offer.partCondition) {
                              'oem' => 'أصلي وكالة',
                              'aftermarket' => 'كوري درجة أولى',
                              'used' => 'مستعمل مفحوص',
                              _ => offer.partCondition,
                            },
                          if (offer.warrantyDays > 0)
                            'ضمان ${offer.warrantyDays} يوم',
                          if (offer.warrantyNote.isNotEmpty) offer.warrantyNote,
                          if (offer.partCondition.isEmpty &&
                              offer.warrantyDays <= 0)
                            'حسب عرض الورشة',
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'السعر الإجمالي',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF45464D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offer.initialPrice == null
                          ? '—'
                          : formatIqd(offer.initialPrice!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isAgency ? _secondary : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canSelect) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: isAgency ? Colors.black : _surfaceHigh,
                  foregroundColor: isAgency ? Colors.white : AppColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAgency ? Icons.check_circle_outline : Icons.done,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAgency
                          ? 'قبول هذا العرض وتأكيد الطلب'
                          : 'قبول هذا العرض',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
