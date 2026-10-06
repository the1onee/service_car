import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barrr/features/shell/role_home.dart';
import 'package:barrr/models/app_user.dart';

import 'support/test_app_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AppUser user(UserRole role) => AppUser(
        id: 'uid-${role.name}',
        role: role,
        name: 'مستخدم',
        phone: '7700000000',
      );

  Future<void> pumpRole(WidgetTester tester, UserRole role) async {
    final session = TestSession(initialUid: user(role).id, profile: user(role));
    addTearDown(session.dispose);
    await tester.pumpWidget(
      session.wrap(
        RoleHome(profile: user(role), homeBuilder: stubRoleHome),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  test('roleHomeKeyFor maps every role', () {
    expect(roleHomeKeyFor(user(UserRole.admin)), 'home-admin');
    expect(roleHomeKeyFor(user(UserRole.oilWorkshop)), 'home-oil-workshop');
    expect(roleHomeKeyFor(user(UserRole.paintShop)), 'home-paint-shop');
    expect(roleHomeKeyFor(user(UserRole.workshop)), 'home-workshop');
    expect(roleHomeKeyFor(user(UserRole.technician)), 'home-technician');
    expect(roleHomeKeyFor(user(UserRole.customer)), 'home-customer');
  });

  testWidgets('admin home key', (tester) async {
    await pumpRole(tester, UserRole.admin);
    expect(find.byKey(const ValueKey('home-admin')), findsOneWidget);
    expect(find.text('stub-home-admin'), findsOneWidget);
  });

  testWidgets('customer home key', (tester) async {
    await pumpRole(tester, UserRole.customer);
    expect(find.byKey(const ValueKey('home-customer')), findsOneWidget);
  });

  testWidgets('technician home key', (tester) async {
    await pumpRole(tester, UserRole.technician);
    expect(find.byKey(const ValueKey('home-technician')), findsOneWidget);
  });

  testWidgets('workshop home key', (tester) async {
    await pumpRole(tester, UserRole.workshop);
    expect(find.byKey(const ValueKey('home-workshop')), findsOneWidget);
  });

  testWidgets('oil workshop home key', (tester) async {
    await pumpRole(tester, UserRole.oilWorkshop);
    expect(find.byKey(const ValueKey('home-oil-workshop')), findsOneWidget);
  });

  testWidgets('paint shop home key', (tester) async {
    await pumpRole(tester, UserRole.paintShop);
    expect(find.byKey(const ValueKey('home-paint-shop')), findsOneWidget);
  });
}
