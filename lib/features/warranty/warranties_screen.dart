import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/job_detail_screen.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranty_claim_screen.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';

class WarrantiesScreen extends StatelessWidget {
  const WarrantiesScreen({
    super.key,
    required this.stream,
    required this.profile,
  });

  final Stream<List<Job>> stream;
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('سجل الضمانات')),
      body: StreamBuilder<List<Job>>(
        stream: stream,
        builder: (context, snap) {
          final rows = (snap.data ?? const <Job>[])
              .where((j) => j.warranty.enabled)
              .toList();
          if (snap.connectionState == ConnectionState.waiting && rows.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا توجد ضمانات بعد. يظهر الضمان هنا بعد أن يفعّله الفني عند إنهاء الطلب.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final active = rows.where((j) => warrantyIsActive(j.warranty)).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              FieldCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تغطية الضمان الميداني',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'زيارة مجانية إذا تكرر العطل خلال مدة الضمان',
                            style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(label: '$active نشط'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final job in rows) ...[
                _WarrantyTile(job: job, profile: profile),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WarrantyTile extends StatelessWidget {
  const _WarrantyTile({required this.job, required this.profile});

  final Job job;
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final active = warrantyIsActive(job.warranty);
    return FieldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.serviceTitle ?? 'خدمة',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              StatusPill(
                label: active ? 'ساري' : 'منتهٍ',
                color: active ? AppColors.emeraldDeep : AppColors.inkSoft,
                background: active ? AppColors.emeraldTint : AppColors.recessed,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${jobCode(job)} · ${warrantyRemainingLabel(job.warranty)}',
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
          ),
          if ((job.technicianName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('الفني: ${job.technicianName}'),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            JobDetailScreen(job: job, profile: profile),
                      ),
                    );
                  },
                  child: const Text('التفاصيل'),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              WarrantyClaimScreen(job: job, profile: profile),
                        ),
                      );
                    },
                    child: const Text('مطالبة'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
