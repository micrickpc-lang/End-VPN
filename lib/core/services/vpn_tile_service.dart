import 'package:flutter/services.dart';

class VpnTileService {
  static final VpnTileService instance = VpnTileService._();
  VpnTileService._();

  static const _channel = MethodChannel('com.example.endvpn/vpn_tile');

  Function()? onTileConnect;
  Function()? onTileDisconnect;

  void init() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onTileConnect':
          onTileConnect?.call();
          break;
        case 'onTileDisconnect':
          onTileDisconnect?.call();
          break;
      }
    });
  }

  /// Вызывать при каждой смене статуса VPN (подключён/отключён)
  Future<void> updateState({required bool connected, String serverName = ''}) async {
    try {
      await _channel.invokeMethod('updateState', {
        'connected': connected,
        'server': serverName,
      });
    } catch (_) {}
  }

  /// Вызывать при смене сервера (VPN уже подключён)
  Future<void> updateServerName(String name) async {
    try {
      await _channel.invokeMethod('updateServerName', {'server': name});
    } catch (_) {}
  }
}