import 'package:cloud_firestore/cloud_firestore.dart';

enum WarrantyClaimStatus {
  open,
  acknowledged,
  inProgress,
  resolved,
  overdue,
}

enum WarrantyClaimResolution {
  partShipped,
  fixedOnsite,
  otherIssueReported,
}

class WarrantyClaim {
  const WarrantyClaim({
    required this.id,
    required this.jobId,
    required this.customerId,
    required this.providerId,
    required this.providerKind,
    required this.claimType,
    required this.status,
    this.customerNote = '',
    this.customerImageUrl = '',
    this.providerNote = '',
    this.otherIssue = false,
    this.otherIssueNote = '',
    this.replacementImageUrl = '',
    this.resolution,
    this.serviceTitle = '',
    this.providerName = '',
    this.providerPhone = '',
    this.respondBy,
    this.createdAt,
    this.acknowledgedAt,
    this.resolvedAt,
    this.updatedAt,
  });

  final String id;
  final String jobId;
  final String customerId;
  final String providerId;
  /// workshop | technician
  final String providerKind;
  final String claimType;
  final WarrantyClaimStatus status;
  final String customerNote;
  final String customerImageUrl;
  final String providerNote;
  final bool otherIssue;
  final String otherIssueNote;
  final String replacementImageUrl;
  final WarrantyClaimResolution? resolution;
  final String serviceTitle;
  final String providerName;
  final String providerPhone;
  final DateTime? respondBy;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime? updatedAt;

  bool get isWorkshop => providerKind == 'workshop';
  bool get isTechnician => providerKind == 'technician';
  bool get isOpen =>
      status == WarrantyClaimStatus.open ||
      status == WarrantyClaimStatus.acknowledged ||
      status == WarrantyClaimStatus.inProgress ||
      status == WarrantyClaimStatus.overdue;
  bool get isResolved => status == WarrantyClaimStatus.resolved;

  /// حالة العرض مع احتساب تجاوز مهلة 24 ساعة محليًا.
  WarrantyClaimStatus get effectiveStatus {
    if (status == WarrantyClaimStatus.resolved) return status;
    if (status == WarrantyClaimStatus.open &&
        respondBy != null &&
        DateTime.now().isAfter(respondBy!)) {
      return WarrantyClaimStatus.overdue;
    }
    return status;
  }

  Duration? get slaRemaining {
    final by = respondBy;
    if (by == null || status != WarrantyClaimStatus.open) return null;
    final left = by.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Map<String, dynamic> toMap() => {
        'jobId': jobId,
        'customerId': customerId,
        'providerId': providerId,
        // توافق أدمن قديم يتوقع technicianId
        'technicianId': providerId,
        'providerKind': providerKind,
        'claimType': claimType,
        'status': statusToFirestore(status),
        'customerNote': customerNote,
        'customerImageUrl': customerImageUrl,
        'providerNote': providerNote,
        'otherIssue': otherIssue,
        'otherIssueNote': otherIssueNote,
        'replacementImageUrl': replacementImageUrl,
        if (resolution != null) 'resolution': resolutionToFirestore(resolution!),
        'serviceTitle': serviceTitle,
        'providerName': providerName,
        'providerPhone': providerPhone,
        'respondBy': respondBy != null ? Timestamp.fromDate(respondBy!) : null,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'acknowledgedAt':
            acknowledgedAt != null ? Timestamp.fromDate(acknowledgedAt!) : null,
        'resolvedAt':
            resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
        'updatedAt': FieldValue.serverTimestamp(),
        // سبب نصي للأدمن القديم
        'reason': claimTypeLabel(claimType),
      };

  factory WarrantyClaim.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return WarrantyClaim.fromMap(doc.id, d);
  }

  factory WarrantyClaim.fromMap(String id, Map<String, dynamic> d) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    final providerId = (d['providerId'] as String?)?.trim().isNotEmpty == true
        ? (d['providerId'] as String).trim()
        : ((d['technicianId'] as String?)?.trim() ?? '');
    return WarrantyClaim(
      id: id,
      jobId: (d['jobId'] as String?)?.trim() ?? '',
      customerId: (d['customerId'] as String?)?.trim() ?? '',
      providerId: providerId,
      providerKind: (d['providerKind'] as String?)?.trim() ?? 'technician',
      claimType: (d['claimType'] as String?)?.trim().isNotEmpty == true
          ? (d['claimType'] as String).trim()
          : ((d['reason'] as String?)?.trim() ?? ''),
      status: statusFromFirestore(d['status'] as String?),
      customerNote: (d['customerNote'] as String?)?.trim() ?? '',
      customerImageUrl: (d['customerImageUrl'] as String?)?.trim() ?? '',
      providerNote: (d['providerNote'] as String?)?.trim() ?? '',
      otherIssue: d['otherIssue'] == true,
      otherIssueNote: (d['otherIssueNote'] as String?)?.trim() ?? '',
      replacementImageUrl: (d['replacementImageUrl'] as String?)?.trim() ?? '',
      resolution: resolutionFromFirestore(d['resolution'] as String?),
      serviceTitle: (d['serviceTitle'] as String?)?.trim() ?? '',
      providerName: (d['providerName'] as String?)?.trim() ?? '',
      providerPhone: (d['providerPhone'] as String?)?.trim() ?? '',
      respondBy: ts(d['respondBy']),
      createdAt: ts(d['createdAt']),
      acknowledgedAt: ts(d['acknowledgedAt']),
      resolvedAt: ts(d['resolvedAt']),
      updatedAt: ts(d['updatedAt']),
    );
  }

  static String statusToFirestore(WarrantyClaimStatus s) => switch (s) {
        WarrantyClaimStatus.open => 'open',
        WarrantyClaimStatus.acknowledged => 'acknowledged',
        WarrantyClaimStatus.inProgress => 'in_progress',
        WarrantyClaimStatus.resolved => 'resolved',
        WarrantyClaimStatus.overdue => 'overdue',
      };

  static WarrantyClaimStatus statusFromFirestore(String? raw) {
    switch (raw) {
      case 'acknowledged':
        return WarrantyClaimStatus.acknowledged;
      case 'in_progress':
        return WarrantyClaimStatus.inProgress;
      case 'resolved':
      case 'approved': // توافق أدمن قديم
        return WarrantyClaimStatus.resolved;
      case 'overdue':
        return WarrantyClaimStatus.overdue;
      case 'rejected':
        return WarrantyClaimStatus.resolved;
      default:
        return WarrantyClaimStatus.open;
    }
  }

  static String resolutionToFirestore(WarrantyClaimResolution r) => switch (r) {
        WarrantyClaimResolution.partShipped => 'part_shipped',
        WarrantyClaimResolution.fixedOnsite => 'fixed_onsite',
        WarrantyClaimResolution.otherIssueReported => 'other_issue_reported',
      };

  static WarrantyClaimResolution? resolutionFromFirestore(String? raw) {
    switch (raw) {
      case 'part_shipped':
        return WarrantyClaimResolution.partShipped;
      case 'fixed_onsite':
        return WarrantyClaimResolution.fixedOnsite;
      case 'other_issue_reported':
        return WarrantyClaimResolution.otherIssueReported;
      default:
        return null;
    }
  }

  static String claimTypeLabel(String type) => switch (type) {
        'part_not_working' => 'القطعة لا تعمل — طلب استبدال',
        'same_fault' => 'عاد العطل نفسه',
        'noise_vibration' => 'صوت أو اهتزاز',
        'incomplete' => 'لم تكتمل الصيانة',
        _ => type.isEmpty ? 'مطالبة ضمان' : type,
      };

  static String statusLabel(WarrantyClaimStatus s) => switch (s) {
        WarrantyClaimStatus.open => 'بانتظار الرد',
        WarrantyClaimStatus.acknowledged => 'تم الرد',
        WarrantyClaimStatus.inProgress => 'قيد المعالجة',
        WarrantyClaimStatus.resolved => 'منتهية',
        WarrantyClaimStatus.overdue => 'متأخرة عن 24 ساعة',
      };

  static String resolutionLabel(WarrantyClaimResolution? r) => switch (r) {
        WarrantyClaimResolution.partShipped => 'تم إرسال قطعة جديدة',
        WarrantyClaimResolution.fixedOnsite => 'تم الحل في الموقع',
        WarrantyClaimResolution.otherIssueReported => 'مشكلة أخرى غير المذكورة',
        null => '',
      };
}
