import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletEntryType { credit, commission, adjustment }

class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.signedAmount,
    required this.balanceAfter,
    this.jobId,
    this.note = '',
    this.createdAt,
  });

  final String id;
  final String userId;
  final WalletEntryType type;
  final double amount;
  final double signedAmount;
  final double balanceAfter;
  final String? jobId;
  final String note;
  final DateTime? createdAt;

  String get typeLabel {
    switch (type) {
      case WalletEntryType.credit:
        return 'شحن';
      case WalletEntryType.commission:
        return 'عمولة';
      case WalletEntryType.adjustment:
        return 'تصحيح';
    }
  }

  factory WalletEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final raw = d['type'] as String? ?? '';
    final type = WalletEntryType.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => WalletEntryType.adjustment,
    );
    final created = d['createdAt'];
    return WalletEntry(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      type: type,
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      signedAmount: (d['signedAmount'] as num?)?.toDouble() ?? 0,
      balanceAfter: (d['balanceAfter'] as num?)?.toDouble() ?? 0,
      jobId: d['jobId'] as String?,
      note: d['note'] as String? ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
