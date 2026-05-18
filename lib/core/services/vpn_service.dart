import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

enum VpnStatus { disconnected, connecting, connected, error }

class VpnService {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  static const _channel = MethodChannel('com.endvpn/xray');
  final _storage = const FlutterSecureStorage();
  final _log = Logger();

  VpnStatus _status = VpnStatus.disconnected;
  VpnStatus get status => _status;

  static const _keySubUrl = 'subscription_url';

  Future<void> saveSubscriptionUrl(String url) async {
    await _storage.write(key: _keySubUrl, value: url);
  }

  Future<String?> getSubscriptionUrl() => _storage.read(key: _keySubUrl);

  Future<bool> connect() async {
    final subUrl = await getSubscriptionUrl();
    if (subUrl == null || subUrl.isEmpty) {
      _log.w('No subscription URL');
      return false;
    }

    _status = VpnStatus.connecting;
    try {
      // Вызываем Kotlin/Native для xray-core
      final result = await _channel.invokeMethod<bool>('startVpn', {
        'subscriptionUrl': subUrl,
      });
      _status = result == true ? VpnStatus.connected : VpnStatus.error;
      return result == true;
    } on MissingPluginException {
      // На Windows/эмуляторе нет нативного канала — мок
      _log.w('VPN channel not available (desktop mock)');
      await Future.delayed(const Duration(seconds: 2));
      _status = VpnStatus.connected;
      return true;
    } catch (e) {
      _log.e('VPN connect error: $e');
      _status = VpnStatus.error;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('stopVpn');
    } on MissingPluginException {
      // мок
    }
    _status = VpnStatus.disconnected;
  }
}
