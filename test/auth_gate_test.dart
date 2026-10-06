import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barrr/features/auth/add_phone_screen.dart';
import 'package:barrr/features/auth/auth_screen.dart';
import 'package:barrr/features/shell/auth_gate.dart';
import 'package:barrr/models/app_user.dart';

import 'support/test_app_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('shows AddPhoneScreen when phone empty', (tester) async {
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

    expect(find.byType(AddPhoneScreen), findsOneWidget);
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
}
