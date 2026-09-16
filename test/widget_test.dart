import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/data/service_catalog.dart';

void main() {
  testWidgets('theme builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Text(AppStrings.appName)),
      ),
    );
    expect(find.text(AppStrings.appName), findsOneWidget);
  });

  test('mvp catalog splits emergency and quote services', () {
    expect(seedServices.length, 10);
    expect(isEmergencyService('towing'), isTrue);
    expect(isEmergencyService('oil'), isFalse);
    expect(AppConstants.defaultLat, closeTo(30.5085, 0.001));
    expect(AppConstants.emergencyTechsPerRound, 2);
    expect(AppConstants.commissionRate, 0.10);
  });
}
