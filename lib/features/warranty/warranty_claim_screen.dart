import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';

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
  final _note = TextEditingController();
  String? _symptom;
  var _busy = false;

  static const _symptoms = [
    'عاد العطل نفسه',
    'القطعة لا تعمل',
    'صوت أو اهتزاز',
    'لم تكتمل الصيانة',
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_symptom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر وصف الخلل أولاً.')),
      );
      return;
    }
    final geo = widget.profile.geo ??
        widget.job.exactLocation ??
        widget.job.approxLocation;
    setState(() => _busy = true);
    try {
      final scope = AppScope.of(context);
      final title = widget.job.serviceTitle ?? 'خدمة';
      final note = _note.text.trim();
      final claimTitle = note.isEmpty
          ? 'ضمان: $title — $_symptom'
          : 'ضمان: $title — $_symptom. $note';
      final jobId = await scope.jobs.createJob(
        customerId: widget.profile.id,
        serviceId: widget.job.serviceId,
        serviceTitle: claimTitle,
        vehicleTypeId: widget.job.vehicleTypeId,
        vehicleTypeTitle: widget.job.vehicleTypeTitle,
        exact: GeoPoint(geo.latitude, geo.longitude),
        isEmergency: true,
        commissionRate: 0,
      );
      await scope.dispatch.dispatch(jobId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم فتح مطالبة الضمان. تابعها من الرئيسية.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال المطالبة: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
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
                    'الضمان نشط · ${warrantyRemainingLabel(job.warranty)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'مطالبة ضمان صيانة سارية',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '${job.serviceTitle ?? 'الخدمة'} · ${jobCode(job)}',
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          const SectionLabel('ما هو الخلل الذي طرأ على المركبة؟'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in _symptoms)
                ChoiceChip(
                  label: Text(item),
                  selected: _symptom == item,
                  onSelected: (_) => setState(() => _symptom = item),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'تفاصيل إضافية للفني',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          const FieldCard(
            child: Text(
              'زيارة الضمان مجانية. يُعاد توجيه فني مناسب لنفس الخدمة دون عمولة جديدة.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'جارٍ التوجيه...' : 'تأكيد طلب فني الضمان'),
          ),
        ],
      ),
    );
  }
}
