import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/legal/privacy_policy.dart';

void main() {
  test('privacy policy is non-empty and points at public Play Store URL', () {
    expect(PrivacyPolicy.version, isNotEmpty);
    expect(PrivacyPolicy.title, contains('خصوصية'));
    expect(PrivacyPolicy.body, contains('سياسة الخصوصية'));
    expect(PrivacyPolicy.body, contains('الموقع'));
    expect(PrivacyPolicy.body, contains('FCM'));
    expect(
      PrivacyPolicy.publicUrl,
      'https://albatariq.com/privacy.html',
    );
    expect(PrivacyPolicy.body, contains(PrivacyPolicy.publicUrl));
  });
}
