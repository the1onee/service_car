import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/models/app_notification.dart';

class NotificationsRepository {
  NotificationsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const systemTtl = Duration(hours: 24);
  static const _closedJobStatuses = {'completed', 'rated', 'cancelled'};

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Cols.notifications);

  Stream<List<AppNotification>> watchForUser(String uid) {
    return _col
        .where('userId', isEqualTo: uid)
        .limit(80)
        .snapshots()
        .asyncMap((snap) async {
      final list = snap.docs.map(AppNotification.fromDoc).toList()
        ..sort((a, b) {
          final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
      return _filterVisible(list);
    });
  }

  Stream<int> watchUnreadCount(String uid) {
    return watchForUser(uid).map((list) => list.where((n) => !n.read).length);
  }

  Future<List<AppNotification>> _filterVisible(
    List<AppNotification> list,
  ) async {
    final now = DateTime.now();
    final jobIds = <String>{};
    for (final n in list) {
      final id = n.jobId?.trim() ?? '';
      if (id.isNotEmpty) jobIds.add(id);
    }

    final closedJobs = await _closedJobIds(jobIds);

    return list.where((n) {
      final created = n.createdAt;
      final withinTtl =
          created != null && now.difference(created) <= systemTtl;
      final jobId = n.jobId?.trim() ?? '';
      if (jobId.isNotEmpty) {
        // طلب مفتوح: يظهر. طلب منتهٍ: يبقى حتى 24 ساعة فقط (مثل إشعار الإكمال).
        if (closedJobs.contains(jobId)) return withinTtl;
        return true;
      }
      // نظامية / بلا طلب: صلاحية 24 ساعة.
      return withinTtl;
    }).toList(growable: false);
  }

  Future<Set<String>> _closedJobIds(Set<String> jobIds) async {
    if (jobIds.isEmpty) return {};
    final closed = <String>{};
    // قراءة كل طلب على حدة. استعلام whereIn على المعرّف ترفضه القواعد
    // لأنها لا تضمن أن كل النتائج تخص المستخدم، فيفشل تحميل الإشعارات.
    await Future.wait(jobIds.map((id) async {
      try {
        final doc = await _db.collection(Cols.jobs).doc(id).get();
        if (!doc.exists) return;
        final status = doc.data()?['status'] as String? ?? '';
        if (_closedJobStatuses.contains(status)) closed.add(id);
      } catch (_) {}
    }));
    return closed;
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
