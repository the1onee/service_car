import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletTopUpStatus { pending, approved, rejected }

class WalletTopUp {
  const WalletTopUp({
    required this.id,
    required this.technicianId,
    required this.amount,
    required this.receiptUrl,
    required this.status,
    this.transferNote = '',
    this.rejectReason = '',
    this.walletEntryId = '',
    this.reviewedBy = '',
    this.createdAt,
    this.reviewedAt,
  });

  final String id;
  final String technicianId;
  final double amount;
  final String receiptUrl;
  final WalletTopUpStatus status;
  final String transferNote;
  final String rejectReason;
  final String walletEntryId;
  final String reviewedBy;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  factory WalletTopUp.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return WalletTopUp(
      id: doc.id,
      technicianId: d['technicianId'] as String? ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      receiptUrl: d['receiptUrl'] as String? ?? '',
      status: _statusOf(d['status'] as String?),
      transferNote: d['transferNote'] as String? ?? '',
      rejectReason: d['rejectReason'] as String? ?? '',
      walletEntryId: d['walletEntryId'] as String? ?? '',
      reviewedBy: d['reviewedBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      reviewedAt: (d['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  static WalletTopUpStatus _statusOf(String? raw) {
    switch (raw) {
      case 'approved':
        return WalletTopUpStatus.approved;
      case 'rejected':
        return WalletTopUpStatus.rejected;
      default:
        return WalletTopUpStatus.pending;
    }
  }

  String get statusLabelAr {
    switch (status) {
      case WalletTopUpStatus.pending:
        return 'بانتظار الموافقة';
      case WalletTopUpStatus.approved:
        return 'تمت إضافة المبلغ';
      case WalletTopUpStatus.rejected:
        return 'مرفوض';
    }
  }
}
