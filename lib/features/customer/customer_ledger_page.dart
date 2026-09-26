import 'package:flutter/material.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/job_detail_screen.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';

class CustomerLedgerPage extends StatelessWidget {
  const CustomerLedgerPage({
    super.key,
    required this.stream,
    required this.profile,
    this.city,
  });

  final Stream<List<Job>> stream;
  final AppUser profile;
  final String? city;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FieldTopBar(
          city: city,
          caption: 'المحفظة',
          trailing: NotificationsBellButton(uid: profile.id),
        ),
        Expanded(
          child: StreamBuilder<List<Job>>(
            stream: stream,
            builder: (context, snap) {
              final jobs = (snap.data ?? const <Job>[])
                  .where((j) =>
                      jobIsDone(j) &&
                      (j.receivedAmount != null || j.finalPrice != null))
                  .toList();
              final total = jobs.fold<double>(
                0,
                (sum, j) => sum + (j.receivedAmount ?? j.finalPrice ?? 0),
              );
              if (snap.connectionState == ConnectionState.waiting &&
                  (snap.data == null)) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'رصيد المحفظة',
                          style: TextStyle(
                            color: Color(0xFF7C839B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatIqd(profile.walletBalance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'الباقي من أي دفعة يبقى هنا وتستطيع استخدامه في طلب آخر',
                          style: TextStyle(color: Color(0xFFBEC6E0), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ما دفعته نقداً للفنيين',
                          style: TextStyle(
                            color: Color(0xFF7C839B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatIqd(total),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${jobs.length} عملية مكتملة',
                          style: const TextStyle(
                              color: Color(0xFFBEC6E0), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const FieldCard(
                    child: Text(
                      AppStrings.cashNote,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionLabel('الحركات الأخيرة'),
                  if (jobs.isEmpty)
                    const FieldCard(
                      child: Text('لا توجد مدفوعات مكتملة بعد.'),
                    )
                  else
                    for (final job in jobs) ...[
                      _PayRow(
                        job: job,
                        onOpen: () => openJobDetail(context, job, profile),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({required this.job, required this.onOpen});

  final Job job;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final amount = job.receivedAmount ?? job.finalPrice ?? 0;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: FieldCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.serviceTitle ?? 'خدمة',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${jobCode(job)} · ${formatWhen(job.createdAt)}',
                    style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              formatIqd(amount),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.emeraldDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
