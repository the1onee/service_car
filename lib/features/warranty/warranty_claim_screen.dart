import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/core/user_error.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranty_claim_logic.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/warranty_claim.dart';
import 'package:barrr/services/warranty_claims_repository.dart';

class WarrantyClaimScreen extends StatefulWidget {
  const WarrantyClaimScreen({
    super.key,
    required this.job,
    required this.profile,
  });

  final Job job;
  final AppUser profile;

  @override
  State<WarrantyClaimScreen> createState() => _WarrantyClaimScreenState();
}

class _WarrantyClaimScreenState extends State<WarrantyClaimScreen> {
  final _repo = WarrantyClaimsRepository();
  final _note = TextEditingController();
  String? _symptom;
  var _busy = false;
  AppUser? _provider;

  static const _techSymptoms = [
    ('same_fault', 'عاد العطل نفسه'),
    ('noise_vibration', 'صوت أو اهتزاز'),
    ('incomplete', 'لم تكتمل الصيانة'),
  ];

  bool get _isWorkshop => claimProviderKindForJob(widget.job) == 'workshop';

  @override
  void initState() {
    super.initState();
    if (_isWorkshop) {
      _symptom = 'part_not_working';
    }
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    final id = (widget.job.technicianId ?? '').trim();
    if (id.isEmpty) return;
    try {
      final user = await AppScope.of(context).users.get(id);
      if (!mounted) return;
      setState(() => _provider = user);
    } catch (_) {}
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!canOpenWarrantyClaim(widget.job)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الضمان غير متاح لهذا الطلب.')),
      );
      return;
    }
    final type = _symptom;
    if (type == null || type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر وصف الخلل أولاً.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.createClaim(
        job: widget.job,
        customerId: widget.profile.id,
        claimType: type,
        customerNote: _note.text.trim(),
        providerName: _provider?.name ?? widget.job.technicianName ?? '',
        providerPhone: _provider?.phone ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم فتح مطالبة الضمان. تابعها من سجل الضمانات.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingError(e, prefix: 'تعذر إرسال المطالبة.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final allowed = canOpenWarrantyClaim(job);
    final name = (_provider?.name.trim().isNotEmpty == true)
        ? _provider!.name.trim()
        : (job.technicianName ?? 'مقدم الخدمة');
    final phone = _provider?.phone.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('مطالبة ضمان')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.emeraldTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    color: AppColors.emeraldDeep),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allowed
                        ? 'الضمان نشط · ${warrantyRemainingLabel(job.warranty)}'
                        : 'الضمان غير متاح لهذا الطلب',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('الضمان', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '${job.serviceTitle ?? 'الخدمة'} · ${jobCode(job)}',
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isWorkshop ? 'الورشة' : 'الفني',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(name),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontFamily: 'monospace',
                    ),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _isWorkshop
                      ? 'ستصل المطالبة للورشة مباشرة خلال مهلة رد 24 ساعة — بدون طلب جديد.'
                      : 'سيظهر تنبيه للفني للتوجه إليك وفحص المشكلة — بدون طلب جديد.',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionLabel('الخلل'),
          if (_isWorkshop)
            ChoiceChip(
              label: Text(WarrantyClaim.claimTypeLabel('part_not_working')),
              selected: true,
              onSelected: (_) {},
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _techSymptoms)
                  ChoiceChip(
                    label: Text(item.$2),
                    selected: _symptom == item.$1,
                    onSelected: (_) => setState(() => _symptom = item.$1),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'ملاحظة للورشة / الفني (اختياري)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (!allowed || _busy) ? null : _submit,
            child: Text(_busy ? 'جارٍ الإرسال' : 'تأكيد المطالبة'),
          ),
        ],
      ),
    );
  }
}
