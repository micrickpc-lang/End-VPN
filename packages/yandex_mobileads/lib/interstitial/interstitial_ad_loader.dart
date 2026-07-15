/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

part of '../mobile_ads.dart';

/// This class is responsible for loading an interstitial ad.
class InterstitialAdLoader extends _FullscreenAdLoader {
  static const _channelPath = 'yandex_mobileads.interstitialAdLoader';
  static const _createChannel =
      MethodChannel('yandex_mobileads.createAdLoader');

  late final _InterstitialAdLoadListener _eventListener;

  InterstitialAdLoader._({
    required int id,
    void Function(InterstitialAd interstitialAd)? onAdLoaded,
    void Function(AdRequestError error)? onAdFailedToLoad,
  }) {
    _channel = MethodChannel('$_channelPath.$id');
    _finalizer.attach(this, _channel, detach: this);
    _eventListener = _InterstitialAdLoadListener(
      channelName: '$_channelPath.$id.events',
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
    _eventListener.setupCallbacks();
  }

  static Future<InterstitialAdLoader> create({
    void Function(InterstitialAd interstitialAd)? onAdLoaded,
    void Function(AdRequestError error)? onAdFailedToLoad,
  }) async {
    int? id = await _createChannel.invokeMethod('interstitialAdLoader');
    if (id == null) {
      throw ArgumentError(
          'something went wrong while creating interstitial ad loader');
    }

    return InterstitialAdLoader._(
      id: id,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }
}
