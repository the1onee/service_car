import 'dart:async';

import 'package:flutter/material.dart';
import 'package:barrr/core/app_brand.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/service_unavailable_screen.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/auth/auth_screen.dart';
import 'package:barrr/features/auth/onboarding_screen.dart';
import 'package:barrr/features/legal/terms_accept_screen.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/shell/role_home.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/services/auth_service.dart';
import 'package:barrr/services/user_repository.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.roleHomeBuilder});

  /// للاختبارات: يستبدل شاشات الأدوار داخل [RoleHome].
  final Widget Function(AppUser profile, String roleKey)? roleHomeBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AppUser? _cached;
  bool? _seenOnboarding;

  @override
  void initState() {
    super.initState();
    readCachedProfile().then((user) {
      if (!mounted) return;
      setState(() => _cached = user);
    });
    hasSeenOnboarding().then((seen) {
      if (!mounted) return;
      setState(() => _seenOnboarding = seen);
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
          final currentUid = scope.auth.currentUid;
          final restoring = snap.connectionState == ConnectionState.waiting &&
              !snap.hasData &&
              !snap.hasError;
          if (restoring) {
            final cached = _cachedFor(currentUid);
            if (currentUid == null || cached == null) {
              return const BrandSplash();
            }
            return _HomeFromProfile(
              seed: cached,
              uid: currentUid,
              roleHomeBuilder: widget.roleHomeBuilder,
            );
          }
          // الخروج يتطلب أن يتفق البث وجلسة Firebase معاً؛ خطأ البث ليس خروجاً.
          final uid = snap.hasError ? currentUid : (snap.data ?? currentUid);
          if (uid == null) {
            final seen = _seenOnboarding;
            if (seen == null) return const BrandSplash();
            if (!seen) {
              return OnboardingScreen(
                onDone: () => setState(() => _seenOnboarding = true),
              );
            }
            return const AuthScreen();
          }
          return _HomeFromProfile(
            seed: _cachedFor(uid),
            uid: uid,
            roleHomeBuilder: widget.roleHomeBuilder,
          );
        },
      ),
    );
  }

  AppUser? _cachedFor(String? uid) {
    final cached = _cached;
    if (uid == null || cached == null || cached.id != uid) return null;
    return cached;
  }
}

class _HomeFromProfile extends StatefulWidget {
  const _HomeFromProfile({
    required this.uid,
    this.seed,
    this.roleHomeBuilder,
  });

  final String uid;
  final AppUser? seed;
  final Widget Function(AppUser profile, String roleKey)? roleHomeBuilder;

  @override
  State<_HomeFromProfile> createState() => _HomeFromProfileState();
}

class _HomeFromProfileState extends State<_HomeFromProfile> {
  static const _maxRetryDelay = Duration(seconds: 30);

  Stream<AppUser?>? _profile;
  Timer? _retry;
  var _retryDelay = const Duration(seconds: 2);

  @override
  void didUpdateWidget(_HomeFromProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _retry?.cancel();
      _profile = null;
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  /// فشل القراءة (صلاحيات قبل إرفاق الرمز أو انقطاع الشبكة) لا يعني غياب الحساب.
  void _scheduleRetry(AppScope scope, Object error) {
    if (_retry?.isActive ?? false) return;
    final delay = _retryDelay;
    authLog('profile read failed: $error; retry in ${delay.inSeconds}s');
    _retry = Timer(delay, () {
      if (!mounted) return;
      scope.users.resetWatch(widget.uid);
      setState(() => _profile = null);
    });
    final next = delay * 2;
    _retryDelay = next > _maxRetryDelay ? _maxRetryDelay : next;
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return StreamBuilder<AppSettings>(
      stream: scope.settings.watchSettings(),
      builder: (context, settings) {
        final minBuild = settings.data?.minAppBuild ?? 0;
        if (AppBrand.buildNumber > 0 && AppBrand.buildNumber < minBuild) {
          return const ServiceUnavailableScreen(updateRequired: true);
        }
        return _profileHome(scope);
      },
    );
  }

  Widget _profileHome(AppScope scope) {
    return StreamBuilder<AppUser?>(
      stream: _profile ??= scope.users.watch(widget.uid),
      builder: (context, profile) {
        if (profile.hasError) _scheduleRetry(scope, profile.error!);
        final appUser = profile.data ?? widget.seed;
        if (appUser == null) {
          final loading = profile.hasError ||
              (profile.connectionState == ConnectionState.waiting &&
                  !profile.hasData);
          if (loading) return const BrandSplash();
          return const _MissingProfile();
        }
        if (!appUser.hasAcceptedCurrentTerms) {
          return TermsAcceptScreen(profile: appUser);
        }
        return RoleHome(
          profile: appUser,
          homeBuilder: widget.roleHomeBuilder,
        );
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
                onPressed: () => signOutFrom(context),
                child: const Text(AppStrings.logout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
