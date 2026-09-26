import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.userId,
    this.type,
    this.jobId,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final String? userId;
  final String? type;
  final String? jobId;
  final bool read;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      title: (d['title'] as String?)?.trim() ?? '',
      body: (d['body'] as String?)?.trim() ?? '',
      userId: d['userId'] as String?,
      type: d['type'] as String?,
      jobId: d['jobId'] as String?,
      read: d['read'] == true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ??
          (d['sentAt'] as Timestamp?)?.toDate(),
    );
  }
}
