import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/services/auth_service.dart';

void main() {
  test('uidChanges forwards session restore and sign-out events', () async {
    final controller = StreamController<String?>();
    addTearDown(controller.close);
    final auth = AuthService(uidChangesOverride: controller.stream);
    final values = <String?>[];
    final subscription = auth.uidChanges.listen(values.add);
    addTearDown(subscription.cancel);

    controller.add('restored-user');
    controller.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(values, ['restored-user', null]);
  });
}
