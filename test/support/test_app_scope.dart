import 'dart:async';

import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/services/auth_service.dart';
import 'package:barrr/services/dispatch_service.dart';
import 'package:barrr/services/fcm_service.dart';
import 'package:barrr/services/job_repository.dart';
import 'package:barrr/services/location_service.dart';
import 'package:barrr/services/settings_repository.dart';
import 'package:barrr/services/user_repository.dart';

typedef RoleHomeBuilder = Widget Function(AppUser profile, String roleKey);

/// شاشة دور خفيفة للاختبار.
Widget stubRoleHome(AppUser profile, String roleKey) {
  return Scaffold(
    body: Center(child: Text('stub-$roleKey')),
  );
}

class TestSession {
  TestSession({
    String? initialUid,
    AppUser? profile,
    bool registering = false,
  }) {
    _uid = initialUid;
    _uidController = StreamController<String?>.broadcast();
    // يبث القيمة الحالية عند الاشتراك ثم يتابع التحديثات (سلوك Behavior).
    final uidStream = () async* {
      yield _uid;
      yield* _uidController.stream;
    }();
    auth = AuthService(
      uidChangesOverride: uidStream,
      currentUidOverride: () => _uid,
    );
    auth.registering.value = registering;
    users = UserRepository(
      watchOverride: (uid) {
        if (profile != null && profile.id == uid) {
          return Stream<AppUser?>.value(profile);
        }
        return Stream<AppUser?>.value(null);
      },
    );
    jobs = JobRepository();
    dispatch = DispatchService(jobs);
    location = LocationService();
    fcm = FcmService(users);
    settings = SettingsRepository();
  }

  late final StreamController<String?> _uidController;
  String? _uid;
  late final AuthService auth;
  late final UserRepository users;
  late final JobRepository jobs;
  late final DispatchService dispatch;
  late final LocationService location;
  late final FcmService fcm;
  late final SettingsRepository settings;

  void setUid(String? uid) {
    _uid = uid;
    if (!_uidController.isClosed) _uidController.add(uid);
  }

  void dispose() {
    auth.registering.dispose();
    _uidController.close();
  }

  Widget wrap(Widget child) {
    return AppScope(
      auth: auth,
      users: users,
      jobs: jobs,
      dispatch: dispatch,
      location: location,
      fcm: fcm,
      settings: settings,
      child: MaterialApp(home: child),
    );
  }
}
