import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/models/warranty.dart';

enum JobStatus {
  dispatching,
  offerPending,
  comparing,
  quoted,
  cancelled,
  noTechnician,
  enRoute,
  arrived,
  finalQuote,
  inProgress,
  completed,
  rated,
}

enum MatchingMode { emergency, quotes }

JobStatus jobStatusFrom(String? raw) {
  return JobStatus.values.firstWhere(
    (s) => s.name == raw,
    orElse: () => JobStatus.dispatching,
  );
}

MatchingMode matchingModeFrom(String? raw, [String? serviceId]) {
  if (raw == MatchingMode.emergency.name) return MatchingMode.emergency;
  if (raw == MatchingMode.quotes.name) return MatchingMode.quotes;
  return isEmergencyService(serviceId ?? '')
      ? MatchingMode.emergency
      : MatchingMode.quotes;
}

class Job {
  const Job({
    required this.id,
    required this.customerId,
    required this.serviceId,
    required this.status,
    required this.approxLocation,
    required this.createdAt,
    this.matchingMode = MatchingMode.quotes,
    this.technicianId,
    this.technicianName,
    this.serviceTitle,
    this.exactLocation,
    this.initialPrice,
    this.finalPrice,
    this.receivedAmount,
    this.commissionAmount,
    this.warranty = const Warranty(enabled: false),
    this.ratings = const JobRatings(),
    this.dispatchRound = 1,
    this.expiresAt,
    this.exactLat,
    this.exactLng,
  });

  final String id;
  final String customerId;
  final String? technicianId;
  final String? technicianName;
  final String serviceId;
  final String? serviceTitle;
  final JobStatus status;
  final MatchingMode matchingMode;
  final GeoPoint approxLocation;
  final GeoPoint? exactLocation;
  final double? exactLat;
  final double? exactLng;
  final double? initialPrice;
  final double? finalPrice;
  final double? receivedAmount;
  final double? commissionAmount;
  final Warranty warranty;
  final JobRatings ratings;
  final int dispatchRound;
  final DateTime? expiresAt;
  final DateTime createdAt;

  bool get isEmergency => matchingMode == MatchingMode.emergency;

  bool get locationRevealed {
    const revealed = {
      JobStatus.enRoute,
      JobStatus.arrived,
      JobStatus.finalQuote,
      JobStatus.inProgress,
      JobStatus.completed,
      JobStatus.rated,
    };
    return revealed.contains(status);
  }

  GeoPoint get displayLocation {
    if (locationRevealed && exactLocation != null) return exactLocation!;
    return approxLocation;
  }

  Map<String, dynamic> toCreateMap() => {
        'customerId': customerId,
        'technicianId': null,
        'technicianName': null,
        'serviceId': serviceId,
        'serviceTitle': serviceTitle,
        'status': status.name,
        'matchingMode': matchingMode.name,
        'approxLocation': approxLocation,
        'exactLocation': exactLocation,
        'initialPrice': initialPrice,
        'finalPrice': finalPrice,
        'receivedAmount': receivedAmount,
        'commissionAmount': commissionAmount,
        'warranty': warranty.toMap(),
        'ratings': ratings.toMap(),
        'dispatchRound': dispatchRound,
        'expiresAt': expiresAt,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory Job.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Job(
      id: doc.id,
      customerId: d['customerId'] as String? ?? '',
      technicianId: d['technicianId'] as String?,
      technicianName: d['technicianName'] as String?,
      serviceId: d['serviceId'] as String? ?? '',
      serviceTitle: d['serviceTitle'] as String?,
      status: jobStatusFrom(d['status'] as String?),
      matchingMode: matchingModeFrom(d['matchingMode'] as String?, d['serviceId'] as String?),
      approxLocation: d['approxLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      exactLocation: d['exactLocation'] as GeoPoint?,
      initialPrice: (d['initialPrice'] as num?)?.toDouble(),
      finalPrice: (d['finalPrice'] as num?)?.toDouble(),
      receivedAmount: (d['receivedAmount'] as num?)?.toDouble(),
      commissionAmount: (d['commissionAmount'] as num?)?.toDouble(),
      warranty: Warranty.fromMap(d['warranty'] as Map<String, dynamic>?),
      ratings: JobRatings.fromMap(d['ratings'] as Map<String, dynamic>?),
      dispatchRound: (d['dispatchRound'] as num?)?.toInt() ?? 1,
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
