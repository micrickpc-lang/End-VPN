import 'dart:io';
import 'package:flutter/services.dart';

class VpnTileService {
  static final VpnTileService instance = VpnTileService._();
  VpnTileService._();

  static const _channel = MethodChannel('com.example.endvpn/vpn_tile');

  Function()? onTileConnect;
  Function()? onTileDisconnect;
  void Function(String status)? onXrayStatus;

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
          onXrayStatus?.call(call.arguments?.toString() ?? '');
          break;
      }
    });
    _consumePendingAction();
  }

  Future<void> _consumePendingAction() async {
    try {
      final action =
          await _channel.invokeMethod<String>('consumePendingTileAction');
      if (action == 'connect') {
        onTileConnect?.call();
      } else if (action == 'disconnect') {
        onTileDisconnect?.call();
      }
    } catch (_) {}
  }

  Future<void> updateState(
      {required bool connected, String serverName = ''}) async {
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
    return await _channel.invokeMethod<bool>('startXray', {
          'config': config,
          'server': server,
        }) ??
        false;
  }

  Future<void> stopXray() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('stopXray');
  }
}
