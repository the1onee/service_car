import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/auth/auth_screen.dart';
import 'package:barrr/features/shell/role_home.dart';
import 'package:barrr/models/app_user.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: scope.auth.registering,
      builder: (context, registering, _) => StreamBuilder<String?>(
        stream: scope.auth.uidChanges,
        builder: (context, snap) {
          // أثناء التسجيل تبقى شاشة المصادقة حتى يُحفظ الملف كاملاً.
          final uid = registering ? null : snap.data;
          if (uid == null) return const AuthScreen();
          return StreamBuilder<AppUser?>(
            stream: scope.users.watch(uid),
            builder: (context, profile) {
              if (profile.connectionState == ConnectionState.waiting &&
                  !profile.hasData) {
                return const _Splash();
              }
              final appUser = profile.data;
              if (appUser == null) return const _MissingProfile();
              return RoleHome(profile: appUser);
            },
          );
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppTheme.brandGradient),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}

/// جلسة صالحة بلا ملف تعريف — يحدث فقط إذا انقطع التسجيل قبل حفظ البيانات.
class _MissingProfile extends StatelessWidget {
  const _MissingProfile();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined,
                  size: 48, color: AppColors.inkSoft),
              const SizedBox(height: 16),
              Text(
                'لم نجد بيانات هذا الحساب. أعد إنشاء الحساب من جديد.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => AppScope.of(context).auth.signOut(),
                child: const Text(AppStrings.logout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
