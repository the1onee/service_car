import 'package:cloud_firestore/cloud_firestore.dart';

class SupportMessage {
  const SupportMessage({
    required this.from,
    required this.body,
    this.createdAt,
  });

  final String from; // user | admin
  final String body;
  final DateTime? createdAt;

  bool get isAdmin => from == 'admin';

  factory SupportMessage.fromMap(Map<String, dynamic> d) {
    final at = d['createdAt'];
    DateTime? createdAt;
    if (at is Timestamp) createdAt = at.toDate();
    return SupportMessage(
      from: (d['from'] as String?)?.trim() ?? 'user',
      body: (d['body'] as String?)?.trim() ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'from': from,
        'body': body,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.subject,
    required this.body,
    required this.status,
    this.messages = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String userRole;
  final String subject;
  final String body;
  final String status; // open | closed
  final List<SupportMessage> messages;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOpen => status != 'closed';

  factory SupportTicket.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final rawMsgs = d['messages'];
    final messages = <SupportMessage>[];
    if (rawMsgs is List) {
      for (final item in rawMsgs) {
        if (item is Map<String, dynamic>) {
          messages.add(SupportMessage.fromMap(item));
        } else if (item is Map) {
          messages.add(
            SupportMessage.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return SupportTicket(
      id: doc.id,
      userId: (d['userId'] as String?)?.trim() ?? '',
      userRole: (d['userRole'] as String?)?.trim() ?? '',
      subject: (d['subject'] as String?)?.trim() ?? '',
      body: (d['body'] as String?)?.trim() ?? '',
      status: (d['status'] as String?)?.trim() ?? 'open',
      messages: messages,
      createdAt: ts(d['createdAt']),
      updatedAt: ts(d['updatedAt']),
    );
  }
}
