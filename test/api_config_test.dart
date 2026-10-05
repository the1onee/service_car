import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/api_config.dart';
import 'package:barrr/core/phone.dart';

void main() {
  group('ApiConfig', () {
    test('uri joins path to base', () {
      final u = ApiConfig.uri('/api/auth/otp/send');
      expect(u.path, '/api/auth/otp/send');
      expect(u.host.isNotEmpty, isTrue);
    });

    test('baseUrl has no trailing slash', () {
      expect(ApiConfig.baseUrl.endsWith('/'), isFalse);
    });

    test('android emulator host when no dart-define', () {
      // في اختبارات الوحدة غالباً ليست أندرويد؛ نتحقق أن القيمة غير فارغة فقط.
      expect(ApiConfig.baseUrl, isNotEmpty);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        expect(ApiConfig.baseUrl, contains('10.0.2.2'));
      }
    });
  });

  group('phone auth email', () {
    test('matches server convention', () {
      expect(phoneAuthEmail('+9647701234567'), '9647701234567@phone.barrr.app');
      expect(looksLikeIraqiMobile(normalizeIraqiPhone('07701234567')), isTrue);
    });
  });
}
