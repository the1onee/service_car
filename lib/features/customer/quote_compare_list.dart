import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/app_snackbar.dart';
import 'package:barrr/core/app_sound.dart';
import 'package:barrr/core/app_svg_icons.dart';
import 'package:barrr/core/user_error.dart';
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
    final wash = job.isWashOrder;
    final tow = job.isTowOrder;
    final tech = job.isTechnicianJob && !tow;
    final emptyLabel = oil
        ? 'بانتظار عروض ورش الزيوت…'
        : wash
            ? 'بانتظار عروض الغسيل…'
            : tow
                ? 'بانتظار عروض السطحة…'
                : (tech ? 'بانتظار عروض الفنيين…' : 'بانتظار العروض');
    final pickLabel = (oil || wash || tow || tech) ? 'قبول الطلب' : 'قبول';

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
                          AppSvgIcons.offerIcon(
                            isWorkshop: oil ||
                                q.isAgencyOilWorkshop ||
                                q.isTrustedOilWorkshop,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              q.technicianName ??
                                  (oil
                                      ? 'ورشة زيوت'
                                      : wash
                                          ? 'مغسل'
                                          : tow
                                              ? 'سطحة'
                                              : 'فني'),
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
                          onPressed: () async {
                            AppSoundService.playAcceptClient();
                            try {
                              final ok = await AppScope.of(context)
                                  .dispatch
                                  .selectOffer(jobId: job.id, offer: q);
                              if (!context.mounted) return;
                              if (!ok) {
                                AppSnackBar.showError(
                                  context,
                                  'تعذّر قبول الطلب. حاول مرة أخرى.',
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              AppSnackBar.showError(
                                context,
                                userFacingError(e, prefix: 'تعذّر قبول الطلب.'),
                              );
                            }
                          },
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
