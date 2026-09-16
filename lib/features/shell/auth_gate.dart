import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/features/auth/auth_screen.dart';
import 'package:barrr/features/shell/role_home.dart';
import 'package:barrr/models/app_user.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return StreamBuilder<String?>(
      stream: scope.auth.uidChanges,
      builder: (context, snap) {
        final uid = snap.data;
        if (uid == null) return const AuthScreen();
        return StreamBuilder<AppUser?>(
          stream: scope.users.watch(uid),
          builder: (context, profile) {
            final appUser = profile.data;
            if (!profile.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (appUser == null) return const AuthScreen();
            return RoleHome(profile: appUser);
          },
        );
      },
    );
  }
}
