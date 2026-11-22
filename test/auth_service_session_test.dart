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

  test('initial null resolves to the user restored from disk', () async {
    final controller = StreamController<String?>();
    addTearDown(controller.close);
    String? currentUid;
    final firstValue = stabilizeInitialAuthUid(
      changes: controller.stream,
      currentUid: () => currentUid,
      restoreDelay: const Duration(milliseconds: 20),
    ).first;

    controller.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    currentUid = 'restored-user';

    expect(await firstValue, 'restored-user');
  });

  test('sign-out after restoration is emitted immediately', () async {
    final values = await stabilizeInitialAuthUid(
      changes: Stream<String?>.fromIterable(['restored-user', null]),
      currentUid: () => null,
      restoreDelay: Duration.zero,
    ).toList();

    expect(values, ['restored-user', null]);
  });
}
