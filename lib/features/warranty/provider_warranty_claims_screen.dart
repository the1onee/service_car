import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/provider_warranty_claim_detail.dart';
import 'package:barrr/features/warranty/warranty_claim_logic.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/warranty_claim.dart';
import 'package:barrr/services/warranty_claims_repository.dart';

/// قائمة مطالبات الضمان لمقدم الخدمة (ورشة أو فني).
class ProviderWarrantyClaimsScreen extends StatelessWidget {
  const ProviderWarrantyClaimsScreen({
    super.key,
    required this.profile,
    this.embedded = false,
  });

  final AppUser profile;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final repo = WarrantyClaimsRepository();
    final body = StreamBuilder<List<WarrantyClaim>>(
      stream: repo.watchForProvider(profile.id),
      builder: (context, snap) {
        final rows = snap.data ?? const <WarrantyClaim>[];
        if (snap.connectionState == ConnectionState.waiting && rows.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (rows.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'لا توجد مطالبات ضمان',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final open = rows.where((c) => c.isOpen).length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            FieldCard(
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'مطالبات الضمان',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusPill(label: '$open مفتوحة'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final claim in rows) ...[
              _ProviderClaimTile(claim: claim, profile: profile),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );

    if (embedded) {
      return ColoredBox(color: AppColors.canvas, child: body);
    }
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('الضمان')),
      body: body,
    );
  }
}

class _ProviderClaimTile extends StatelessWidget {
  const _ProviderClaimTile({required this.claim, required this.profile});

  final WarrantyClaim claim;
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final status = claim.effectiveStatus;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProviderWarrantyClaimDetail(
                claimId: claim.id,
                profile: profile,
              ),
            ),
          );
        },
        child: FieldCard(
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
              if (claim.customerNote.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  claim.customerNote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                slaRemainingLabel(claim),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: status == WarrantyClaimStatus.overdue
                      ? const Color(0xFFB45309)
                      : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
