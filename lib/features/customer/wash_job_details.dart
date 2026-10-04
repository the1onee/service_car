import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';

/// بطاقة تفاصيل طلب الغسيل — للعميل والفني.
class WashJobDetailsCard extends StatelessWidget {
  const WashJobDetailsCard({
    super.key,
    required this.packageName,
    this.vehicleTypeTitle,
    this.carSummary = '',
    this.landmark = '',
    this.customerPhone = '',
    this.partNote = '',
    this.distanceKm,
    this.compact = false,
    this.showPhone = false,
  });

  factory WashJobDetailsCard.fromJob(
    Job job, {
    bool compact = false,
    bool showPhone = false,
  }) {
    return WashJobDetailsCard(
      packageName: job.washDisplayTitle,
      vehicleTypeTitle: job.vehicleTypeTitle,
      carSummary: job.carSummary,
      landmark: job.landmark,
      customerPhone: job.customerPhone,
      partNote: job.partNote,
      compact: compact,
      showPhone: showPhone,
    );
  }

  factory WashJobDetailsCard.fromOffer(
    JobOffer offer, {
    bool compact = false,
  }) {
    return WashJobDetailsCard(
      packageName: offer.washDisplayTitle,
      vehicleTypeTitle: offer.vehicleTypeTitle,
      carSummary: offer.carSummary,
      landmark: offer.landmark,
      partNote: offer.partNote,
      distanceKm: offer.distanceKm,
      compact: compact,
    );
  }

  final String packageName;
  final String? vehicleTypeTitle;
  final String carSummary;
  final String landmark;
  final String customerPhone;
  final String partNote;
  final double? distanceKm;
  final bool compact;
  final bool showPhone;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String value) {
      if (value.trim().isEmpty) return;
      rows.add(_Row(label: label, value: value));
    }

    addRow('باقة الغسيل', packageName);
    addRow('نوع المركبة', vehicleTypeTitle ?? '');
    addRow('السيارة', carSummary);
    addRow('علامة دالة', landmark);
    addRow('تفاصيل الغسيل', partNote);
    if (distanceKm != null) {
      addRow('المسافة التقريبية', '${distanceKm!.toStringAsFixed(1)} كم');
    }
    if (showPhone) addRow('هاتف العميل', customerPhone);

    if (rows.isEmpty) return const SizedBox.shrink();

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          const Text(
            'تفاصيل الغسيل',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );

    if (compact) return body;
    return FieldCard(child: body);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textDirection: RegExp(r'^\+?\d').hasMatch(value.trim())
                ? TextDirection.ltr
                : TextDirection.rtl,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
