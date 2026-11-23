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

  test('emits currentUser immediately when already restored', () async {
    final controller = StreamController<String?>();
    addTearDown(controller.close);
    final first = restoreThenFollowAuthUid(
      changes: controller.stream,
      currentUid: () => 'restored-user',
      expectSession: () async => true,
    ).first;

    expect(await first, 'restored-user');
  });

  test('initial null waits for a slow restore when a session is expected',
      () async {
    final controller = StreamController<String?>();
    addTearDown(controller.close);
    final values = <String?>[];
    final subscription = restoreThenFollowAuthUid(
      changes: controller.stream,
      currentUid: () => null,
      expectSession: () async => true,
      restoreTimeout: const Duration(milliseconds: 500),
      pollInterval: const Duration(milliseconds: 20),
    ).listen(values.add);
    addTearDown(subscription.cancel);

    controller.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(values, isEmpty);

    controller.add('restored-user');
    await Future<void>.delayed(Duration.zero);
    expect(values, ['restored-user']);
  });

  test('polling picks up currentUser restored without an event', () async {
    final controller = StreamController<String?>();
    addTearDown(controller.close);
    String? currentUid;
    final first = restoreThenFollowAuthUid(
      changes: controller.stream,
      currentUid: () => currentUid,
      expectSession: () async => true,
      restoreTimeout: const Duration(seconds: 2),
      pollInterval: const Duration(milliseconds: 10),
    ).first;

    controller.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    currentUid = 'restored-user';

    expect(await first, 'restored-user');
  });

  test('no saved session resolves to null without waiting', () async {
    final controller = StreamController<String?>();
    addTearDown(controller.close);
    final first = restoreThenFollowAuthUid(
      changes: controller.stream,
      currentUid: () => null,
      expectSession: () async => false,
      restoreTimeout: const Duration(seconds: 30),
    ).first.timeout(const Duration(seconds: 1));

    controller.add(null);

    expect(await first, isNull);
  });

  test('timeout resolves to null when the session never restores', () async {
    final controller = StreamController<String?>();
    addTearDown(controller.close);
    final first = restoreThenFollowAuthUid(
      changes: controller.stream,
      currentUid: () => null,
      expectSession: () async => true,
      restoreTimeout: const Duration(milliseconds: 50),
      pollInterval: const Duration(milliseconds: 10),
    ).first;

    controller.add(null);

    expect(await first, isNull);
  });

  test('sign-out after restoration is emitted immediately', () async {
    final values = await restoreThenFollowAuthUid(
      changes: Stream<String?>.fromIterable(['restored-user', null]),
      currentUid: () => null,
      expectSession: () async => true,
    ).toList();

    expect(values, ['restored-user', null]);
  });

  test('stream errors fall back to currentUser instead of signing out',
      () async {
    final controller = StreamController<String?>();
    addTearDown(controller.close);
    final values = <String?>[];
    final subscription = restoreThenFollowAuthUid(
      changes: controller.stream,
      currentUid: () => 'restored-user',
    ).listen(values.add, onError: (_) => fail('error must not surface'));
    addTearDown(subscription.cancel);

    controller.addError(StateError('channel'));
    await Future<void>.delayed(Duration.zero);

    expect(values, ['restored-user']);
  });
}
