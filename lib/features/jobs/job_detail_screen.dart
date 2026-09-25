import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/jobs/rating_sheet.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranty_claim_screen.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';

void openJobDetail(BuildContext context, Job job, AppUser profile) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => JobDetailScreen(job: job, profile: profile),
    ),
  );
}

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({
    super.key,
    required this.job,
    required this.profile,
  });

  final Job job;
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final stream = profile.isTechnician
        ? scope.jobs.watchRecentForTechnician(profile.id)
        : scope.jobs.watchRecentForCustomer(profile.id);
    return StreamBuilder<List<Job>>(
      stream: stream,
      builder: (context, snap) {
        final rows = snap.data ?? const <Job>[];
        Job live = job;
        for (final row in rows) {
          if (row.id == job.id) {
            live = row;
            break;
          }
        }
        return _Body(job: live, profile: profile);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.job, required this.profile});

  final Job job;
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final colors = jobStatusColors(job.status);
    final price = job.receivedAmount ?? job.finalPrice ?? job.initialPrice;
    final customer = !profile.isTechnician;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(jobCode(job))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.serviceTitle ?? 'طلب خدمة',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ),
                    StatusPill(
                      label: jobStatusLabel(job.status),
                      color: colors.$1,
                      background: colors.$2,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formatWhen(job.createdAt),
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
                if (jobIsOpen(job)) ...[
                  const SizedBox(height: 14),
                  _Progress(status: job.status),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if ((customer ? job.technicianName : null) != null ||
              (job.technicianName ?? '').isNotEmpty)
            FieldCard(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.recessed,
                    child: Text(_initial(job.technicianName)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.technicianName ?? 'فني',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Text(
                          'الفني المعيّن',
                          style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const StatusPill(
                    label: 'معتمد',
                    icon: Icons.verified_outlined,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'الحساب',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _MoneyRow(label: 'السعر المبدئي', value: job.initialPrice),
                _MoneyRow(label: 'السعر النهائي', value: job.finalPrice),
                _MoneyRow(label: 'المبلغ المستلم نقداً', value: job.receivedAmount),
                if (!customer && job.commissionAmount != null)
                  _MoneyRow(label: 'عمولة المنصة', value: job.commissionAmount),
                const Divider(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'المبلغ الظاهر',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      price == null ? '—' : formatIqd(price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: AppColors.emeraldDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  AppStrings.cashNote,
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
              ],
            ),
          ),
          if (job.warranty.enabled) ...[
            const SizedBox(height: 12),
            _WarrantyCard(job: job, customer: customer, profile: profile),
          ],
          if (customer &&
              (job.status == JobStatus.completed || job.status == JobStatus.rated) &&
              job.ratings.customerToTech == null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _rate(context),
              child: const Text('تقييم الفني'),
            ),
          ],
          if (job.ratings.customerToTech != null) ...[
            const SizedBox(height: 12),
            FieldCard(
              child: Text('تقييمك للفني: ${job.ratings.customerToTech} / 5'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rate(BuildContext context) async {
    final jobs = AppScope.of(context).jobs;
    final users = AppScope.of(context).users;
    final stars = await showRatingSheet(context, title: 'قيّم الفني');
    if (stars == null || !context.mounted) return;
    await jobs.rateAsCustomer(job.id, stars);
    if (job.technicianId != null) {
      await users.applyRating(job.technicianId!, stars);
    }
    await jobs.markRatedIfDone(job.id);
  }
}

class _WarrantyCard extends StatelessWidget {
  const _WarrantyCard({
    required this.job,
    required this.customer,
    required this.profile,
  });

  final Job job;
  final bool customer;
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final active = warrantyIsActive(job.warranty);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.emeraldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: AppColors.emeraldDeep),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ضمان الإصلاح',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(
                label: active ? 'ساري' : warrantyRemainingLabel(job.warranty),
                color: active ? AppColors.emeraldDeep : AppColors.inkSoft,
                background: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(warrantyLabel(job.warranty)),
          const SizedBox(height: 4),
          Text(
            warrantyRemainingLabel(job.warranty),
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
          ),
          if (customer && active) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        WarrantyClaimScreen(job: job, profile: profile),
                  ),
                );
              },
              child: const Text('رفع مطالبة بالضمان'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          ),
          Text(
            value == null ? '—' : formatIqd(value!),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _initial(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty) return 'ف';
  return trimmed.substring(0, 1);
}

class _Progress extends StatelessWidget {
  const _Progress({required this.status});

  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    const labels = ['القبول', 'الطريق', 'الفحص', 'العمل'];
    final active = switch (status) {
      JobStatus.dispatching || JobStatus.offerPending || JobStatus.comparing || JobStatus.quoted => 0,
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
