import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/phone.dart';

void main() {
  group('normalizeIraqiPhone', () {
    test('local formats to E.164', () {
      expect(normalizeIraqiPhone('07701234567'), '+9647701234567');
      expect(normalizeIraqiPhone('7701234567'), '+9647701234567');
      expect(normalizeIraqiPhone('+9647701234567'), '+9647701234567');
      expect(normalizeIraqiPhone('9647701234567'), '+9647701234567');
      expect(normalizeIraqiPhone('009647701234567'), '+9647701234567');
    });

    test('strips spaces and dashes', () {
      expect(normalizeIraqiPhone('0770 123 4567'), '+9647701234567');
      expect(normalizeIraqiPhone('0770-123-4567'), '+9647701234567');
    });

    test('converts arabic-indic digits', () {
      expect(normalizeIraqiPhone('٠٧٧٠١٢٣٤٥٦٧'), '+9647701234567');
    });
  });

  group('looksLikeIraqiMobile', () {
    test('accepts +9647xxxxxxxxx only', () {
      expect(looksLikeIraqiMobile('+9647701234567'), isTrue);
      expect(looksLikeIraqiMobile('+9641601234567'), isFalse);
      expect(looksLikeIraqiMobile('+964770123456'), isFalse);
      expect(looksLikeIraqiMobile('07701234567'), isFalse);
    });
  });

  group('prettyIraqiPhone', () {
    test('formats readable local style', () {
      expect(prettyIraqiPhone('+9647701234567'), '0770 123 4567');
    });

    test('returns raw when not iraqi mobile', () {
      expect(prettyIraqiPhone('+9641601234567'), '+9641601234567');
    });
  });

  group('phoneAuthEmail / resolveAuthEmail', () {
    test('builds internal email', () {
      expect(phoneAuthEmail('+9647701234567'), '9647701234567@phone.barrr.app');
    });

    test('resolveAuthEmail accepts phone or email', () {
      expect(resolveAuthEmail('07701234567'), '9647701234567@phone.barrr.app');
      expect(resolveAuthEmail('User@Example.com'), 'user@example.com');
    });

    test('resolveAuthEmail rejects invalid input', () {
      expect(() => resolveAuthEmail('not-an-email'), throwsFormatException);
      expect(() => resolveAuthEmail('bad@'), throwsFormatException);
    });

    test('phoneFromIdentifier', () {
      expect(phoneFromIdentifier('07701234567'), '+9647701234567');
      expect(phoneFromIdentifier('a@b.com'), '');
    });
  });
}
