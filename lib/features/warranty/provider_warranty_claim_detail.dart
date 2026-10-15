import 'package:flutter/material.dart';
import 'package:barrr/core/app_snackbar.dart';
import 'package:barrr/core/cloudinary_config.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/core/user_error.dart';
import 'package:barrr/features/shared/app_network_or_data_image.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranty_claim_logic.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/warranty_claim.dart';
import 'package:barrr/services/cloudinary_upload.dart';
import 'package:barrr/services/warranty_claims_repository.dart';

class ProviderWarrantyClaimDetail extends StatefulWidget {
  const ProviderWarrantyClaimDetail({
    super.key,
    required this.claimId,
    required this.profile,
  });

  final String claimId;
  final AppUser profile;

  @override
  State<ProviderWarrantyClaimDetail> createState() =>
      _ProviderWarrantyClaimDetailState();
}

class _ProviderWarrantyClaimDetailState
    extends State<ProviderWarrantyClaimDetail> {
  final _repo = WarrantyClaimsRepository();
  final _note = TextEditingController();
  final _otherNote = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _note.dispose();
    _otherNote.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      AppSnackBar.showSuccess(context, ok);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        userFacingError(e, prefix: 'تعذر تنفيذ الإجراء.'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shipPart(WarrantyClaim claim) async {
    setState(() => _busy = true);
    try {
      var imageUrl = '';
      try {
        imageUrl = await CloudinaryUpload().pickAndUpload(
          folder: CloudinaryConfig.folderParts,
          tags: const ['warranty_replacement'],
          imageQuality: 55,
          maxWidth: 1280,
        );
      } catch (e) {
        if (e.toString().contains('cancelled')) {
          // صورة اختيارية — يمكن الإكمال بدونها.
        } else {
          rethrow;
        }
      }
      await _repo.resolvePartShipped(
        claimId: claim.id,
        providerId: widget.profile.id,
        replacementImageUrl: imageUrl,
        providerNote: _note.text.trim(),
      );
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'تم تسجيل إرسال القطعة الجديدة.');
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('cancelled')) return;
      AppSnackBar.showError(
        context,
        userFacingError(e, prefix: 'تعذر تسجيل الإرسال.'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportOther(WarrantyClaim claim) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('مشكلة أخرى'),
          content: TextField(
            controller: _otherNote,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'وصف المشكلة المختلفة عن شكوى العميل',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _otherNote.text.trim()),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
    if (note == null || !mounted) return;
    await _run(
      () => _repo.resolveOtherIssue(
        claimId: claim.id,
        providerId: widget.profile.id,
        otherIssueNote: note,
      ),
      'تم تسجيل وجود مشكلة أخرى.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('تفاصيل مطالبة الضمان')),
      body: StreamBuilder<WarrantyClaim?>(
        stream: _repo.watchClaim(widget.claimId),
        builder: (context, snap) {
          final claim = snap.data;
          if (snap.connectionState == ConnectionState.waiting &&
              claim == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (claim == null) {
            return const Center(child: Text('المطالبة غير موجودة'));
          }
          final status = claim.effectiveStatus;
          final open = claim.isOpen;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (claim.isTechnician && open)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.directions_car_outlined),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ضمان — توجّه للعميل لفحص المشكلة وحلّها.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              FieldCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            claim.serviceTitle.isEmpty
                                ? 'مطالبة ضمان'
                                : claim.serviceTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        StatusPill(
                          label: WarrantyClaim.statusLabel(status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(WarrantyClaim.claimTypeLabel(claim.claimType)),
                    const SizedBox(height: 6),
                    Text(
                      slaRemainingLabel(claim),
                      style: TextStyle(
                        color: status == WarrantyClaimStatus.overdue
                            ? const Color(0xFFB45309)
                            : AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (claim.customerNote.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const SectionLabel('ملاحظة العميل'),
                      Text(claim.customerNote),
                    ],
                    if (claim.customerImageUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: AppNetworkOrDataImage(
                            source: claim.customerImageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                    if (claim.resolution != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        WarrantyClaim.resolutionLabel(claim.resolution),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                    if (claim.otherIssue) ...[
                      const SizedBox(height: 8),
                      Text(
                        'مشكلة أخرى: ${claim.otherIssueNote}',
                        style: const TextStyle(color: Color(0xFFB45309)),
                      ),
                    ],
                    if (claim.replacementImageUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: AppNetworkOrDataImage(
                            source: claim.replacementImageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (open) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة الرد (اختياري)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (status == WarrantyClaimStatus.open ||
                    status == WarrantyClaimStatus.overdue)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () => _repo.acknowledge(
                                claimId: claim.id,
                                providerId: widget.profile.id,
                                providerNote: _note.text.trim(),
                              ),
                              'تم تسجيل الرد.',
                            ),
                    child: const Text('تأكيد استلام المطالبة / رد أولي'),
                  ),
                if (claim.isWorkshop) ...[
                  const SizedBox(height: 8),
                  if (status != WarrantyClaimStatus.inProgress)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () => _repo.markInProgress(
                                  claimId: claim.id,
                                  providerId: widget.profile.id,
                                ),
                                'جارٍ تجهيز الاستبدال.',
                              ),
                      child: const Text('بدء تجهيز قطعة بديلة'),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : () => _shipPart(claim),
                    child: Text(
                      _busy
                          ? 'جارٍ…'
                          : 'تم إرسال قطعة جديدة للعميل',
                    ),
                  ),
                ],
                if (claim.isTechnician) ...[
                  const SizedBox(height: 8),
                  if (status != WarrantyClaimStatus.inProgress)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () => _repo.markInProgress(
                                  claimId: claim.id,
                                  providerId: widget.profile.id,
                                ),
                                'تم تسجيل التوجه للعميل.',
                              ),
                      child: const Text('في الطريق / جاري الفحص'),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () => _repo.resolveFixedOnsite(
                                claimId: claim.id,
                                providerId: widget.profile.id,
                                providerNote: _note.text.trim(),
                              ),
                              'تم إغلاق المطالبة — حل في الموقع.',
                            ),
                    child: const Text('تم الحل في الموقع'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _reportOther(claim),
                    child: const Text('هناك مشكلة أخرى غير التي ذكرها العميل'),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
