import 'dart:async';

import 'package:endvpn/core/services/ad_load_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waits for the SDK load callback after the request returns', () async {
    final gate = AdLoadGate();
    var completed = false;
    final result = gate.request(
      start: () async {},
      timeout: const Duration(seconds: 1),
    )..then((_) => completed = true);

    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    gate.loaded();
    expect(await result, isTrue);
  });

  test('shares one native request with concurrent callers', () async {
    final gate = AdLoadGate();
    var requests = 0;
    Future<void> start() async {
      requests++;
    }

    final first = gate.request(
      start: start,
      timeout: const Duration(seconds: 1),
    );
    final second = gate.request(
      start: start,
      timeout: const Duration(seconds: 1),
    );
    expect(requests, 1);
    expect(identical(first, second), isTrue);

    gate.failed();
    expect(await first, isFalse);
    expect(await second, isFalse);
  });

  test('times out and permits a later retry', () async {
    final gate = AdLoadGate();
    var cancellations = 0;
    final timedOut = gate.request(
      start: () async {},
      timeout: Duration.zero,
      onTimeout: () async {
        cancellations++;
      },
    );

    expect(await timedOut, isFalse);
    expect(cancellations, 1);

    final retry = gate.request(
      start: () async {},
      timeout: const Duration(seconds: 1),
    );
    gate.loaded();
    expect(await retry, isTrue);
  });

  test('timeout covers a native request that never acknowledges', () async {
    final gate = AdLoadGate();
    final nativeRequest = Completer<void>();
    var cancelled = false;

    expect(
      await gate.request(
        start: () => nativeRequest.future,
        timeout: Duration.zero,
        onTimeout: () async => cancelled = true,
      ),
      isFalse,
    );
    expect(cancelled, isTrue);
    nativeRequest.complete();
  });

  test('native request errors do not block future attempts', () async {
    final gate = AdLoadGate();
    await expectLater(
      gate.request(
        start: () async => throw StateError('native load failed'),
        timeout: const Duration(seconds: 1),
      ),
      throwsStateError,
    );

    final retry = gate.request(
      start: () async {},
      timeout: const Duration(seconds: 1),
    );
    gate.loaded();
    expect(await retry, isTrue);
  });
}
