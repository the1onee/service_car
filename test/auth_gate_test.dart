import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barrr/features/auth/auth_screen.dart';
import 'package:barrr/features/auth/onboarding_screen.dart';
import 'package:barrr/features/shell/auth_gate.dart';
import 'package:barrr/legal/terms_of_use.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/services/user_repository.dart';

import 'support/test_app_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_seen_v1': true});
  });

  AppUser user({
    required String id,
    UserRole role = UserRole.customer,
    String phone = '7701234567',
  }) {
    return AppUser(
      id: id,
      role: role,
      name: 'اختبار',
      phone: phone,
      termsAcceptedVersion: AppTerms.version,
    );
  }

  testWidgets('shows AuthScreen when no session', (tester) async {
    final session = TestSession(initialUid: null);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      session.wrap(AuthGate(roleHomeBuilder: stubRoleHome)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('shows onboarding on first launch without session',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = TestSession(initialUid: null);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      session.wrap(AuthGate(roleHomeBuilder: stubRoleHome)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('shows AuthScreen while registering', (tester) async {
    final session = TestSession(
      initialUid: 'u1',
      profile: user(id: 'u1'),
      registering: true,
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      session.wrap(AuthGate(roleHomeBuilder: stubRoleHome)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('shows role home when phone empty', (tester) async {
    final session = TestSession(
      initialUid: 'u2',
      profile: user(id: 'u2', phone: ''),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      session.wrap(AuthGate(roleHomeBuilder: stubRoleHome)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('home-customer')), findsOneWidget);
  });

  testWidgets('shows role home stub when profile complete', (tester) async {
    final session = TestSession(
      initialUid: 'u3',
      profile: user(id: 'u3', role: UserRole.customer),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      session.wrap(AuthGate(roleHomeBuilder: stubRoleHome)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('home-customer')), findsOneWidget);
    expect(find.text('stub-home-customer'), findsOneWidget);
  });

  testWidgets('returns to AuthScreen when the session signs out',
      (tester) async {
    final session = TestSession(
      initialUid: 'u4',
      profile: user(id: 'u4'),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      session.wrap(AuthGate(roleHomeBuilder: stubRoleHome)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-customer')), findsOneWidget);

    session.setUid(null);
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('shows missing-profile recovery for a valid session',
      (tester) async {
    final session = TestSession(initialUid: 'u5');
    addTearDown(session.dispose);

    await tester.pumpWidget(
      session.wrap(AuthGate(roleHomeBuilder: stubRoleHome)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('لم نجد بيانات هذا الحساب. أعد إنشاء الحساب من جديد.'),
      findsOneWidget,
    );
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('uses matching cached profile when auth stream errors',
      (tester) async {
    final cached = user(id: 'u6');
    await saveCachedProfile(cached);
    final session = TestSession(
      initialUid: 'u6',
      profile: cached,
      uidStreamOverride: Stream<String?>.error(StateError('auth stream')),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      session.wrap(AuthGate(roleHomeBuilder: stubRoleHome)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-customer')), findsOneWidget);
  });

  testWidgets('does not use a cached profile for another session',
      (tester) async {
    await saveCachedProfile(user(id: 'old-user'));
    final session = TestSession(
      initialUid: 'u7',
      uidStreamOverride: Stream<String?>.error(StateError('auth stream')),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      session.wrap(AuthGate(roleHomeBuilder: stubRoleHome)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
  });
}
