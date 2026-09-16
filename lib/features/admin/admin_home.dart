import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/models/app_user.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final users = AppScope.of(context).users;
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التوثيق'),
        actions: [
          IconButton(
            onPressed: () => AppScope.of(context).auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: users.watchTechnicians(),
        builder: (context, snap) {
          final list = snap.data ?? const <AppUser>[];
          if (list.isEmpty) {
            return const Center(child: Text('لا يوجد فنيون بعد'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final t = list[i];
              return ListTile(
                title: Text(t.name.isEmpty ? t.email : t.name),
                subtitle: Text(
                  '${t.verificationStatus.name} — محفظة ${t.walletBalance.toStringAsFixed(0)} د.ع\n${t.phone}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (!t.verified)
                      FilledButton(
                        onPressed: () => users.setVerification(uid: t.id, approved: true),
                        child: const Text('قبول'),
                      ),
                    IconButton(
                      onPressed: () => users.setVerification(uid: t.id, approved: false),
                      icon: const Icon(Icons.block),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
