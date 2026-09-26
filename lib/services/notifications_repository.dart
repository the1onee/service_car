import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/models/app_notification.dart';

class NotificationsRepository {
  NotificationsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Cols.notifications);

  Stream<List<AppNotification>> watchForUser(String uid) {
    return _col
        .where('userId', isEqualTo: uid)
        .limit(80)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(AppNotification.fromDoc).toList()
        ..sort((a, b) {
          final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
      return list;
    });
  }

  Stream<int> watchUnreadCount(String uid) {
    return watchForUser(uid).map((list) => list.where((n) => !n.read).length);
  }

  Future<void> markRead(String id) {
    return _col.doc(id).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllRead(String uid) async {
    final snap = await _col.where('userId', isEqualTo: uid).limit(80).get();
    final batch = _db.batch();
    var n = 0;
    for (final d in snap.docs) {
      if (d.data()['read'] == true) continue;
      batch.update(d.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      n++;
      if (n >= 40) break;
    }
    if (n > 0) await batch.commit();
  }
}
