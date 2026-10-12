import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/support_ticket.dart';

class SupportRepository {
  SupportRepository({FirebaseFirestore? db}) : _injected = db;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Cols.supportTickets);

  Stream<List<SupportTicket>> watchMine(String uid) {
    return _col.where('userId', isEqualTo: uid).limit(40).snapshots().map((snap) {
      final rows = snap.docs.map(SupportTicket.fromDoc).toList();
      rows.sort((a, b) {
        final aa = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bb.compareTo(aa);
      });
      return rows;
    });
  }

  Future<String> createTicket({
    required AppUser user,
    required String subject,
    required String body,
  }) async {
    final subj = subject.trim();
    final text = body.trim();
    if (subj.length < 3) throw StateError('اكتب موضوعاً أوضح.');
    if (text.length < 3) throw StateError('اكتب تفاصيل التعليق.');

    final ref = await _col.add({
      'subject': subj,
      'body': text,
      'userId': user.id,
      'userRole': user.role.name,
      'status': 'open',
      'messages': [
        {
          'from': 'user',
          'body': text,
          'createdAt': Timestamp.now(),
        },
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> appendUserMessage({
    required String ticketId,
    required String uid,
    required String body,
  }) async {
    final text = body.trim();
    if (text.length < 2) throw StateError('اكتب رسالة قبل الإرسال.');
    final ref = _col.doc(ticketId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('التذكرة غير موجودة.');
      final data = snap.data()!;
      if ((data['userId'] as String?) != uid) {
        throw StateError('لا تملك هذه التذكرة.');
      }
      if ((data['status'] as String?) == 'closed') {
        throw StateError('التذكرة مغلقة.');
      }
      final msgs = List<Map<String, dynamic>>.from(
        (data['messages'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [],
      );
      msgs.add({
        'from': 'user',
        'body': text,
        'createdAt': Timestamp.now(),
      });
      tx.update(ref, {
        'messages': msgs,
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });
    });
  }
}
