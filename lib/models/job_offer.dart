import 'package:cloud_firestore/cloud_firestore.dart';

enum OfferStatus { pending, submitted, accepted, expired, rejected }

class JobOffer {
  const JobOffer({
    required this.id,
    required this.jobId,
    required this.technicianId,
    required this.status,
    required this.expiresAt,
    this.serviceTitle,
    this.approxLocation,
    this.initialPrice,
    this.technicianName,
    this.ratingAvg = 5,
    this.distanceKm,
    this.verified = false,
  });

  final String id;
  final String jobId;
  final String technicianId;
  final OfferStatus status;
  final DateTime expiresAt;
  final String? serviceTitle;
  final GeoPoint? approxLocation;
  final double? initialPrice;
  final String? technicianName;
  final double ratingAvg;
  final double? distanceKm;
  final bool verified;

  int remainingSeconds() {
    final s = expiresAt.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  factory JobOffer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final raw = d['status'] as String? ?? 'pending';
    return JobOffer(
      id: doc.id,
      jobId: d['jobId'] as String? ?? '',
      technicianId: d['technicianId'] as String? ?? '',
      status: OfferStatus.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => OfferStatus.pending,
      ),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      serviceTitle: d['serviceTitle'] as String?,
      approxLocation: d['approxLocation'] as GeoPoint?,
      initialPrice: (d['initialPrice'] as num?)?.toDouble(),
      technicianName: d['technicianName'] as String?,
      ratingAvg: (d['ratingAvg'] as num?)?.toDouble() ?? 5,
      distanceKm: (d['distanceKm'] as num?)?.toDouble(),
      verified: d['verified'] as bool? ?? false,
    );
  }
}
