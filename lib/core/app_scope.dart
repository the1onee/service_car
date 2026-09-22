import 'package:flutter/material.dart';
import 'package:barrr/services/auth_service.dart';
import 'package:barrr/services/dispatch_service.dart';
import 'package:barrr/services/fcm_service.dart';
import 'package:barrr/services/job_repository.dart';
import 'package:barrr/services/location_service.dart';
import 'package:barrr/services/settings_repository.dart';
import 'package:barrr/services/user_repository.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.auth,
    required this.users,
    required this.jobs,
    required this.dispatch,
    required this.location,
    required this.fcm,
    required this.settings,
    required super.child,
  });

  final AuthService auth;
  final UserRepository users;
  final JobRepository jobs;
  final DispatchService dispatch;
  final LocationService location;
  final FcmService fcm;
  final SettingsRepository settings;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
