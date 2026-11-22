import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/services/auth_service.dart';

void main() {
  test('customer create fields omit ratingAvg so rules allow the write', () {
    final fields = customerCreateFields(
      uid: 'u1',
      name: 'محمد',
      phone: '+9647701234567',
      photoUrl: '',
      email: '',
      authProvider: 'phone',
    );

    expect(fields.containsKey('ratingAvg'), isFalse);
    expect(fields.containsKey('oilWorkshopTier'), isFalse);
    expect(fields.containsKey('adminLevel'), isFalse);
    expect(fields.containsKey('adminPermissions'), isFalse);
    expect(fields.containsKey('disabled'), isFalse);
    expect(fields.containsKey('commissionRate'), isFalse);
    expect(fields['role'], 'customer');
    expect(fields['verified'], isTrue);
    expect(fields['verificationStatus'], 'approved');
    expect(fields['walletBalance'], 0);
    expect(fields['ratingCount'], 0);
    expect(fields['commissionPercent'], 0);
    expect(fields['name'], 'محمد');
    expect(fields['phone'], '+9647701234567');
    expect(fields['email'], '');
    expect(fields['authProvider'], 'phone');
  });
}
