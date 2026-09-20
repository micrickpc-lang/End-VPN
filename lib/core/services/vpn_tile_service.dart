import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class VpnTileService {
  static final VpnTileService instance = VpnTileService._();
  VpnTileService._();

  static const _channel = MethodChannel('com.example.endvpn/vpn_tile');

  Function()? onTileConnect;
  Function()? onTileDisconnect;
  void Function(String status)? onXrayStatus;
  final _xrayStatuses = StreamController<String>.broadcast();
  int _nextXrayRequestId = DateTime.now().microsecondsSinceEpoch;
  int? _activeXrayRequestId;
  String? lastXrayError;

  void init() {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onTileConnect':
          onTileConnect?.call();
          break;
        case 'onTileDisconnect':
          onTileDisconnect?.call();
          break;
        case 'onXrayStatus':
          final details = call.arguments;
          final status = details is Map
              ? details['status']?.toString() ?? ''
              : details?.toString() ?? '';
          final error = details is Map ? details['error']?.toString() : null;
          final requestId = details is Map ? details['requestId'] : null;
          if (requestId == null || requestId != _activeXrayRequestId) break;
          if (error != null && error.isNotEmpty) lastXrayError = error;
          _xrayStatuses.add(status);
          onXrayStatus?.call(status);
          break;
      }
    });
    _consumePendingAction();
  }

  Future<void> _consumePendingAction() async {
    try {
      final action = await _channel.invokeMethod<String>(
        'consumePendingTileAction',
      );
      if (action == 'connect') {
        onTileConnect?.call();
      } else if (action == 'disconnect') {
        onTileDisconnect?.call();
      }
    } catch (_) {}
  }

  Future<void> updateState({
    required bool connected,
    String serverName = '',
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateState', {
        'connected': connected,
        'server': serverName,
      });
    } catch (_) {}
  }

  Future<void> updateServerName(String name) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateServerName', {'server': name});
    } catch (_) {}
  }

  Future<bool> startXray(String config, String server) async {
    if (!Platform.isAndroid) return false;
    lastXrayError = null;
    final requestId = ++_nextXrayRequestId;
    _activeXrayRequestId = requestId;
    var confirmed = false;
    final started = Completer<bool>();
    final subscription = _xrayStatuses.stream.listen((status) {
      if (started.isCompleted) return;
      switch (status.toLowerCase()) {
        case 'started':
          started.complete(true);
          break;
        case 'error':
        case 'stopped':
          started.complete(false);
          break;
      }
    });
    try {
      final launched =
          await _channel.invokeMethod<bool>('startXray', {
            'config': config,
            'server': server,
            'requestId': requestId,
          }) ??
          false;
      if (!launched) return false;
      confirmed = await started.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          lastXrayError ??= 'VPN core did not confirm startup';
          return false;
        },
      );
      if (!confirmed && lastXrayError == 'VPN core did not confirm startup') {
        await stopXray();
      }
      return confirmed;
    } finally {
      await subscription.cancel();
      if (!confirmed && _activeXrayRequestId == requestId) {
        _activeXrayRequestId = null;
      }
    }
  }

  Future<void> stopXray() async {
    if (!Platform.isAndroid) return;
    final previousRequestId = _activeXrayRequestId;
    _activeXrayRequestId = null;
    try {
      await _channel.invokeMethod('stopXray');
    } catch (_) {
      _activeXrayRequestId = previousRequestId;
      rethrow;
    }
  }
}
