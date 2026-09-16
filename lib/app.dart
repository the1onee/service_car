import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/shell/auth_gate.dart';
import 'package:barrr/services/auth_service.dart';
import 'package:barrr/services/dispatch_service.dart';
import 'package:barrr/services/fcm_service.dart';
import 'package:barrr/services/job_repository.dart';
import 'package:barrr/services/location_service.dart';
import 'package:barrr/services/user_repository.dart';

class FanniApp extends StatelessWidget {
  FanniApp({super.key, required this.firebaseReady});

  final bool firebaseReady;
  final _auth = AuthService();
  final _users = UserRepository();
  final _jobs = JobRepository();
  final _location = LocationService();

  @override
  Widget build(BuildContext context) {
    final dispatch = DispatchService(_jobs);
    final fcm = FcmService(_users);
    return AppScope(
      auth: _auth,
      users: _users,
      jobs: _jobs,
      dispatch: dispatch,
      location: _location,
      fcm: fcm,
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: firebaseReady
            ? const AuthGate()
            : const _FirebaseMissingScreen(),
      ),
    );
  }
}

class _FirebaseMissingScreen extends StatelessWidget {
  const _FirebaseMissingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'تعذر تهيئة Firebase.\nشغّل flutterfire configure وضع ملف google-services.json ثم أعد التشغيل.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
