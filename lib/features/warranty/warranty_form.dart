import 'package:flutter/material.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/models/warranty.dart';

class WarrantyForm extends StatelessWidget {
  const WarrantyForm({
    super.key,
    required this.enabled,
    required this.type,
    required this.note,
    required this.onEnabled,
    required this.onType,
    required this.onNote,
  });

  final bool enabled;
  final WarrantyType type;
  final String note;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<WarrantyType> onType;
  final ValueChanged<String> onNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('إضافة ضمان لمدة ${AppConstants.warrantyDays} يوم'),
          subtitle: const Text('على القطعة أو على العملية'),
          value: enabled,
          onChanged: onEnabled,
        ),
        if (enabled) ...[
          SegmentedButton<WarrantyType>(
            segments: const [
              ButtonSegment(value: WarrantyType.part, label: Text('على القطعة')),
              ButtonSegment(value: WarrantyType.work, label: Text('على العملية')),
            ],
            selected: {type},
            onSelectionChanged: (s) => onType(s.first),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(labelText: 'ملاحظة الضمان (اختياري)'),
            onChanged: onNote,
          ),
        ],
      ],
    );
  }
}

String warrantyLabel(Warranty w) {
  if (!w.enabled) return 'بدون ضمان';
  final kind = w.type == WarrantyType.part ? 'القطعة' : 'العملية';
  final until = warrantyEndsAt(w);
  if (until == null) return 'ضمان $kind لمدة ${w.days} يوم';
  return 'ضمان $kind حتى ${until.year}/${until.month}/${until.day}';
}

DateTime? warrantyEndsAt(Warranty w) {
  if (!w.enabled || w.startsAt == null) return null;
  final days = w.days == 0 ? AppConstants.warrantyDays : w.days;
  return w.startsAt!.add(Duration(days: days));
}

bool warrantyIsActive(Warranty w) {
  final end = warrantyEndsAt(w);
  return end != null && end.isAfter(DateTime.now());
}

String warrantyRemainingLabel(Warranty w) {
  final end = warrantyEndsAt(w);
  if (end == null) return w.enabled ? 'بانتظار تفعيل الضمان' : 'بدون ضمان';
  final left = end.difference(DateTime.now());
  if (left.isNegative) return 'انتهى الضمان';
  if (left.inHours < 1) return 'متبقي أقل من ساعة';
  if (left.inHours < 48) return 'متبقي ${left.inHours} ساعة';
  return 'متبقي ${left.inDays} يوم';
}
