import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barrr/features/customer/customer_account_page.dart';
import 'package:barrr/legal/terms_of_use.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';

import 'support/test_app_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('groups account settings without duplicate tab shortcuts',
      (tester) async {
    final profile = AppUser(
      id: 'customer-1',
      role: UserRole.customer,
      name: 'محمد',
      phone: '+9647701234567',
      termsAcceptedVersion: AppTerms.version,
    );
    final session = TestSession(initialUid: profile.id, profile: profile);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      session.wrap(
        CustomerAccountPage(
          profile: profile,
          jobs: Stream<List<Job>>.value(const []),
          city: 'بغداد',
          topBarTrailing: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('بياناتي'), findsOneWidget);
    expect(find.text('الطلبات'), findsNothing);
    expect(find.text('المحفظة'), findsNothing);
    expect(find.text('تحديد عنوانك'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('الخصوصية'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('إعدادات التطبيق'), findsOneWidget);
    expect(find.text('الخصوصية'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('المساعدة'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('المساعدة'), findsOneWidget);
  });
}
