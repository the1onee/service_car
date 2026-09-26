import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/features/jobs/job_detail_screen.dart';
import 'package:barrr/models/app_notification.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/services/notifications_repository.dart';

Future<void> openNotifications(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
  );
}

class NotificationsBellButton extends StatelessWidget {
  const NotificationsBellButton({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final repo = NotificationsRepository();
    return StreamBuilder<int>(
      stream: repo.watchUnreadCount(uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return IconButton(
          tooltip: 'الإشعارات',
          onPressed: () => openNotifications(context),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final uid = scope.auth.currentUid;
    final repo = NotificationsRepository();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          if (uid != null)
            TextButton(
              onPressed: () => repo.markAllRead(uid),
              child: const Text('تعليم الكل كمقروء'),
            ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('سجّل الدخول لعرض الإشعارات'))
          : StreamBuilder<List<AppNotification>>(
              stream: repo.watchForUser(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('تعذّر التحميل: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return const Center(child: Text('لا توجد إشعارات بعد'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final n = list[i];
                    return Material(
                      color: n.read ? AppColors.surface : AppColors.amberTint,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          if (!n.read) await repo.markRead(n.id);
                          final jobId = n.jobId?.trim();
                          if (jobId == null ||
                              jobId.isEmpty ||
                              !context.mounted) {
                            return;
                          }
                          scope.fcm.focusJobId.value = jobId;
                          final jobSnap = await FirebaseFirestore.instance
                              .collection(Cols.jobs)
                              .doc(jobId)
                              .get();
                          if (!jobSnap.exists || !context.mounted) return;
                          final profile = await scope.users.get(uid);
                          if (profile == null || !context.mounted) return;
                          openJobDetail(
                            context,
                            Job.fromDoc(jobSnap),
                            profile,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title.isEmpty ? 'إشعار' : n.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: n.read
                                            ? AppColors.ink
                                            : AppColors.amberDeep,
                                      ),
                                    ),
                                  ),
                                  if (!n.read)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.amberDeep,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              if (n.body.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  n.body,
                                  style: const TextStyle(
                                    color: AppColors.inkSoft,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              if (n.createdAt != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _formatWhen(n.createdAt!),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  static String _formatWhen(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }
}
