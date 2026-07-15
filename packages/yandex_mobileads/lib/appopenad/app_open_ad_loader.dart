/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

part of '../mobile_ads.dart';

/// This class is responsible for loading an app open ad.
class AppOpenAdLoader extends _FullscreenAdLoader {
  static const _channelPath = 'yandex_mobileads.appOpenAdLoader';
  static const _createChannel =
      MethodChannel('yandex_mobileads.createAdLoader');

  late final _AppOpenAdLoadListener _eventListener;

  AppOpenAdLoader._({
    required int id,
    void Function(AppOpenAd appOpenAd)? onAdLoaded,
    void Function(AdRequestError error)? onAdFailedToLoad,
  }) {
    _channel = MethodChannel('$_channelPath.$id');
    _finalizer.attach(this, _channel, detach: this);
    _eventListener = _AppOpenAdLoadListener(
      channelName: '$_channelPath.$id.events',
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
    _eventListener.setupCallbacks();
  }

  static Future<AppOpenAdLoader> create({
    void Function(AppOpenAd appOpenAd)? onAdLoaded,
    void Function(AdRequestError error)? onAdFailedToLoad,
  }) async {
    int? id = await _createChannel.invokeMethod('appOpenAdLoader');
    if (id == null) {
      throw ArgumentError(
          'something went wrong while creating app open ad loader');
    }

    return AppOpenAdLoader._(
      id: id,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }
}
