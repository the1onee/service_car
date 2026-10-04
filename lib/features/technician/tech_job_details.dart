import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/shared/app_network_or_data_image.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';

/// بطاقة تفاصيل طلب الفني — للعرض والتنفيذ.
class TechJobDetailsCard extends StatelessWidget {
  const TechJobDetailsCard({
    super.key,
    this.serviceTitle = '',
    this.vehicleTypeTitle,
    this.carSummary = '',
    this.partNote = '',
    this.partImageUrl = '',
    this.landmark = '',
    this.customerPhone = '',
    this.distanceKm,
    this.compact = false,
    this.showPhone = false,
  });

  factory TechJobDetailsCard.fromJob(
    Job job, {
    bool compact = false,
    bool showPhone = false,
  }) {
    return TechJobDetailsCard(
      serviceTitle: job.serviceTitle ?? '',
      vehicleTypeTitle: job.vehicleTypeTitle,
      carSummary: job.carSummary,
      partNote: job.partNote,
      partImageUrl: job.partImageUrl,
      landmark: job.landmark,
      customerPhone: job.customerPhone,
      compact: compact,
      showPhone: showPhone,
    );
  }

  factory TechJobDetailsCard.fromOffer(
    JobOffer offer, {
    bool compact = false,
  }) {
    return TechJobDetailsCard(
      serviceTitle: offer.serviceTitle ?? '',
      vehicleTypeTitle: offer.vehicleTypeTitle,
      carSummary: offer.carSummary,
      partNote: offer.partNote,
      partImageUrl: offer.partImageUrl,
      landmark: offer.landmark,
      distanceKm: offer.distanceKm,
      compact: compact,
    );
  }

  final String serviceTitle;
  final String? vehicleTypeTitle;
  final String carSummary;
  final String partNote;
  final String partImageUrl;
  final String landmark;
  final String customerPhone;
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

    addRow('الخدمة', serviceTitle);
    addRow('نوع المركبة', vehicleTypeTitle ?? '');
    addRow('السيارة', carSummary);
    addRow('وصف العطل', partNote);
    addRow('علامة دالة', landmark);
    if (distanceKm != null) {
      addRow('المسافة التقريبية', '${distanceKm!.toStringAsFixed(1)} كم');
    }
    if (showPhone) addRow('هاتف العميل', customerPhone);

    final image = partImageUrl.trim();
    if (rows.isEmpty && image.isEmpty) return const SizedBox.shrink();

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          const Text(
            'تفاصيل الطلب',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) const SizedBox(height: 6),
        ],
        if (image.isNotEmpty) ...[
          if (rows.isNotEmpty) const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: AppNetworkOrDataImage(source: image, fit: BoxFit.cover),
            ),
          ),
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
