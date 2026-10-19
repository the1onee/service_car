import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/core/service_unavailable_screen.dart';
import 'package:barrr/features/shell/auth_gate.dart';
import 'package:barrr/services/auth_service.dart';
import 'package:barrr/services/dispatch_service.dart';
import 'package:barrr/services/fcm_service.dart';
import 'package:barrr/services/job_repository.dart';
import 'package:barrr/services/location_service.dart';
import 'package:barrr/services/settings_repository.dart';
import 'package:barrr/services/user_repository.dart';

class FanniApp extends StatelessWidget {
  FanniApp({
    super.key,
    required this.firebaseReady,
    this.onRetryFirebase,
  });

  final bool firebaseReady;
  final Future<void> Function()? onRetryFirebase;
  final _auth = AuthService();
  final _users = UserRepository();
  final _jobs = JobRepository();
  final _location = LocationService();
  final _settings = SettingsRepository();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final dispatch = DispatchService(_jobs);
    final fcm = FcmService(_users, messengerKey: _messengerKey);
    return AppScope(
      auth: _auth,
      users: _users,
      jobs: _jobs,
      dispatch: dispatch,
      location: _location,
      fcm: fcm,
      settings: _settings,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeModeNotifier,
        builder: (context, currentThemeMode, _) => MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messengerKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: currentThemeMode,
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
              : ServiceUnavailableScreen(onRetry: onRetryFirebase),
        ),
      ),
    );
  }
}
