import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/user_error.dart';

void main() {
  test('permission-denied maps to Arabic in release', () {
    final msg = userFacingError(
      FirebaseException(plugin: 'firestore', code: 'permission-denied'),
    );
    expect(msg, contains('صلاحية'));
  });

  test('auth wrong-password is user friendly', () {
    final msg = userFacingError(
      FirebaseAuthException(code: 'wrong-password'),
    );
    expect(msg, contains('كلمة المرور'));
  });

  test('unknown error does not leak exception class name', () {
    final msg = userFacingError(Exception('internal stack trace detail'));
    expect(msg.toLowerCase(), isNot(contains('exception')));
  });
}
