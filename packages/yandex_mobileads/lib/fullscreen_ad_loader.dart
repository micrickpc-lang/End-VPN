/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

part of 'mobile_ads.dart';

abstract class _FullscreenAdLoader {
  static const _pluginType = 'plugin_type';
  static const _pluginVersion = 'plugin_version';
  static const _flutter = 'flutter';

  static const _createChannel =
      MethodChannel('yandex_mobileads.createAdLoader');

  late final MethodChannel _channel;

  /// Loads a fullscreen ad with the given [AdRequestConfiguration].
  Future<void> loadAd({AdRequestConfiguration? adRequestConfiguration}) async {
    final map = adRequestConfiguration?._toMap() ?? {};
    map['parameters'] = {
      _pluginType: _flutter,
      _pluginVersion: MobileAds.pluginVersion,
    }..addAll(adRequestConfiguration?.parameters ?? {});
    _channel.invokeMethod('load', map);
  }

  Future<void> cancelLoading() async {
    _channel.invokeMethod('cancelLoading');
  }

  Future<void> destroy() async {
    _channel.invokeMethod('destroy');
    _finalizer.detach(this);
  }
}
