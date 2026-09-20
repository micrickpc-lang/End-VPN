import 'dart:async';

/// Waits for the ad SDK's load callback rather than its request acknowledgment.
class AdLoadGate {
  Future<bool>? _inFlight;
  Completer<bool>? _pending;

  Future<bool> request({
    required Future<void> Function() start,
    required Duration timeout,
    Future<void> Function()? onTimeout,
  }) {
    return _inFlight ??= _wait(start, timeout, onTimeout).whenComplete(() {
      _inFlight = null;
    });
  }

  Future<bool> _wait(
    Future<void> Function() start,
    Duration timeout,
    Future<void> Function()? onTimeout,
  ) async {
    final pending = Completer<bool>();
    _pending = pending;
    try {
      Future<bool> waitForCallback() async {
        await start();
        return pending.future;
      }

      return await waitForCallback().timeout(
        timeout,
        onTimeout: () async {
          await onTimeout?.call();
          if (!pending.isCompleted) pending.complete(false);
          return false;
        },
      );
    } finally {
      if (identical(_pending, pending)) _pending = null;
    }
  }

  void loaded() => _complete(true);

  void failed() => _complete(false);

  void _complete(bool success) {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(success);
  }
}
