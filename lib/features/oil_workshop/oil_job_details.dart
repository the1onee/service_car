import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';

/// بطاقة تفاصيل طلب الزيت — للعرض والتنفيذ وتفاصيل الطلب.
class OilJobDetailsCard extends StatelessWidget {
  const OilJobDetailsCard({
    super.key,
    required this.oilTypeName,
    this.vehicleTypeTitle,
    this.carSummary = '',
    this.cylinders = 0,
    this.liters = 0,
    this.includeOilFilter = false,
    this.landmark = '',
    this.customerPhone = '',
    this.partNote = '',
    this.distanceKm,
    this.compact = false,
    this.showPhone = false,
  });

  factory OilJobDetailsCard.fromJob(
    Job job, {
    bool compact = false,
    bool showPhone = false,
  }) {
    return OilJobDetailsCard(
      oilTypeName: job.oilDisplayTitle,
      vehicleTypeTitle: job.vehicleTypeTitle,
      carSummary: job.carSummary,
      cylinders: job.cylinders,
      liters: job.liters,
      includeOilFilter: job.includeOilFilter,
      landmark: job.landmark,
      customerPhone: job.customerPhone,
      partNote: job.partNote,
      compact: compact,
      showPhone: showPhone,
    );
  }

  factory OilJobDetailsCard.fromOffer(
    JobOffer offer, {
    bool compact = false,
  }) {
    return OilJobDetailsCard(
      oilTypeName: offer.oilDisplayTitle,
      vehicleTypeTitle: offer.vehicleTypeTitle,
      carSummary: offer.carSummary,
      cylinders: offer.cylinders,
      liters: offer.liters,
      includeOilFilter: offer.includeOilFilter,
      landmark: offer.landmark,
      partNote: offer.partNote,
      distanceKm: offer.distanceKm,
      compact: compact,
    );
  }

  final String oilTypeName;
  final String? vehicleTypeTitle;
  final String carSummary;
  final int cylinders;
  final double liters;
  final bool includeOilFilter;
  final String landmark;
  final String customerPhone;
  final String partNote;
  final double? distanceKm;
  final bool compact;
  final bool showPhone;

  bool get _hasStructured =>
      oilTypeName.trim().isNotEmpty ||
      cylinders > 0 ||
      liters > 0 ||
      carSummary.isNotEmpty ||
      (vehicleTypeTitle ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String value) {
      if (value.trim().isEmpty) return;
      rows.add(_OilDetailRow(label: label, value: value));
    }

    addRow('نوع الزيت', oilTypeName);
    addRow('نوع المركبة', vehicleTypeTitle ?? '');
    addRow('السيارة', carSummary);
    if (cylinders > 0) addRow('السلندر', '$cylinders');
    if (liters > 0) addRow('الكمية المتوقعة', '${liters.toStringAsFixed(1)} لتر');
    if (_hasStructured || includeOilFilter) {
      addRow('فلتر الزيت (السيفون)', includeOilFilter ? 'نعم' : 'لا');
    }
    addRow('علامة دالة', landmark);
    if (distanceKm != null) {
      addRow('المسافة التقريبية', '${distanceKm!.toStringAsFixed(1)} كم');
    }
    if (showPhone) addRow('هاتف العميل', customerPhone);

    if (rows.isEmpty && partNote.trim().isNotEmpty) {
      rows.add(
        Text(
          partNote.trim(),
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
      );
    } else if (!_hasStructured &&
        partNote.trim().isNotEmpty &&
        oilTypeName.trim().isEmpty) {
      rows.add(
        Text(
          partNote.trim(),
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          const Text(
            'تفاصيل تبديل الزيت',
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

class _OilDetailRow extends StatelessWidget {
  const _OilDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
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
