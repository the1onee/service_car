import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/job_detail_screen.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranty_claim_logic.dart';
import 'package:barrr/features/warranty/warranty_claim_screen.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/warranty_claim.dart';
import 'package:barrr/services/warranty_claims_repository.dart';

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
    final claimsRepo = WarrantyClaimsRepository();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('سجل الضمانات')),
      body: StreamBuilder<List<WarrantyClaim>>(
        stream: claimsRepo.watchForCustomer(profile.id),
        builder: (context, claimsSnap) {
          final claims = claimsSnap.data ?? const <WarrantyClaim>[];
          return StreamBuilder<List<Job>>(
            stream: stream,
            builder: (context, snap) {
              final rows = (snap.data ?? const <Job>[])
                  .where((j) => j.warranty.enabled && jobSupportsWarrantyClaims(j))
                  .toList();
              if (snap.connectionState == ConnectionState.waiting &&
                  rows.isEmpty &&
                  claims.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (rows.isEmpty && claims.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا توجد ضمانات',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final active =
                  rows.where((j) => warrantyIsActive(j.warranty)).length;
              final openClaims = claims.where((c) => c.isOpen).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  FieldCard(
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'الضمان',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusPill(label: '$active نشط'),
                      ],
                    ),
                  ),
                  if (openClaims.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'مطالبات مفتوحة',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final claim in openClaims) ...[
                      _CustomerClaimTile(claim: claim),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (rows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'الضمانات',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final job in rows) ...[
                      _WarrantyTile(
                        job: job,
                        profile: profile,
                        openClaim: _openClaimForJob(claims, job.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

WarrantyClaim? _openClaimForJob(List<WarrantyClaim> claims, String jobId) {
  for (final c in claims) {
    if (c.jobId == jobId && c.isOpen) return c;
  }
  return null;
}

class _CustomerClaimTile extends StatelessWidget {
  const _CustomerClaimTile({required this.claim});

  final WarrantyClaim claim;

  @override
  Widget build(BuildContext context) {
    final status = claim.effectiveStatus;
    return FieldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  claim.serviceTitle.isEmpty
                      ? WarrantyClaim.claimTypeLabel(claim.claimType)
                      : claim.serviceTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              StatusPill(
                label: WarrantyClaim.statusLabel(status),
                color: status == WarrantyClaimStatus.overdue
                    ? const Color(0xFFB45309)
                    : AppColors.emeraldDeep,
                background: status == WarrantyClaimStatus.overdue
                    ? const Color(0xFFFFF4D6)
                    : AppColors.emeraldTint,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            WarrantyClaim.claimTypeLabel(claim.claimType),
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
          ),
          if (claim.providerName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${claim.isWorkshop ? 'الورشة' : 'الفني'}: ${claim.providerName}'
              '${claim.providerPhone.isNotEmpty ? ' · ${claim.providerPhone}' : ''}',
            ),
          ],
          if (claim.customerNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(claim.customerNote),
          ],
          if (claim.providerNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'رد مقدم الخدمة: ${claim.providerNote}',
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ],
          if (claim.otherIssue) ...[
            const SizedBox(height: 6),
            Text(
              'مشكلة أخرى: ${claim.otherIssueNote}',
              style: const TextStyle(
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            slaRemainingLabel(claim),
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _WarrantyTile extends StatelessWidget {
  const _WarrantyTile({
    required this.job,
    required this.profile,
    this.openClaim,
  });

  final Job job;
  final AppUser profile;
  final WarrantyClaim? openClaim;

  @override
  Widget build(BuildContext context) {
    final active = warrantyIsActive(job.warranty);
    final canClaim = canOpenWarrantyClaim(job) && openClaim == null;
    return FieldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.serviceTitle ?? 'خدمة',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              StatusPill(
                label: active ? 'ساري' : 'منتهٍ',
                color: active ? AppColors.emeraldDeep : AppColors.inkSoft,
                background:
                    active ? AppColors.emeraldTint : AppColors.recessed,
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
            Text(
              '${job.isPartsOrder ? 'الورشة' : 'الفني'}: ${job.technicianName}',
            ),
          ],
          if (openClaim != null) ...[
            const SizedBox(height: 8),
            StatusPill(
              label:
                  'مطالبة: ${WarrantyClaim.statusLabel(openClaim!.effectiveStatus)}',
            ),
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
              if (canClaim) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => WarrantyClaimScreen(
                            job: job,
                            profile: profile,
                          ),
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
