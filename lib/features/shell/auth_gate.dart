import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/auth/auth_screen.dart';
import 'package:barrr/features/shell/role_home.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/services/user_repository.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AppUser? _cached;

  @override
  void initState() {
    super.initState();
    readCachedProfile().then((user) {
      if (!mounted) return;
      setState(() => _cached = user);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: scope.auth.registering,
      builder: (context, registering, _) => StreamBuilder<String?>(
        stream: scope.auth.uidChanges,
        builder: (context, snap) {
          // أثناء التسجيل تبقى شاشة المصادقة حتى يُحفظ الملف كاملاً.
          if (registering) return const AuthScreen();
          final cached = _cached;
          final currentUid = scope.auth.currentUid;
          if (cached != null &&
              currentUid != null &&
              cached.id == currentUid &&
              (snap.connectionState == ConnectionState.waiting ||
                  snap.data == currentUid)) {
            return _HomeFromProfile(seed: cached, uid: currentUid);
          }
          // الجلسة تنتظر قراءة الملف؛ لا نعرض الدخول قبل أن يصدر البث قيمة.
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const BrandSplash();
          }
          final uid = snap.data;
          if (uid == null) return const AuthScreen();
          return _HomeFromProfile(uid: uid);
        },
      ),
    );
  }
}

class _HomeFromProfile extends StatelessWidget {
  const _HomeFromProfile({required this.uid, this.seed});

  final String uid;
  final AppUser? seed;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return StreamBuilder<AppUser?>(
      stream: scope.users.watch(uid),
      builder: (context, profile) {
        final appUser = profile.data ?? seed;
        if (appUser == null) {
          if (profile.connectionState == ConnectionState.waiting &&
              !profile.hasData) {
            return const BrandSplash();
          }
          return const _MissingProfile();
        }
        return RoleHome(profile: appUser);
      },
    );
  }
}

class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

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
