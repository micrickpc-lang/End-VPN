/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

part of '../mobile_ads.dart';

/// This class is responsible for loading an rewarded ad.
class RewardedAdLoader extends _FullscreenAdLoader {
  static const _channelPath = 'yandex_mobileads.rewardedAdLoader';

  late final _RewardedAdLoadListener _eventListener;

  RewardedAdLoader._({
    required int id,
    void Function(RewardedAd rewardedAd)? onAdLoaded,
    void Function(AdRequestError error)? onAdFailedToLoad,
  }) {
    _channel = MethodChannel('$_channelPath.$id');
    _finalizer.attach(this, _channel, detach: this);
    _eventListener = _RewardedAdLoadListener(
      channelName: '$_channelPath.$id.events',
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
    _eventListener.setupCallbacks();
  }

  static Future<RewardedAdLoader> create({
    void Function(RewardedAd rewardedAd)? onAdLoaded,
    void Function(AdRequestError error)? onAdFailedToLoad,
  }) async {
    int? id = await _FullscreenAdLoader._createChannel
        .invokeMethod('rewardedAdLoader');
    if (id == null) {
      throw ArgumentError(
          'something went wrong while creating rewarded ad loader');
    }

    return RewardedAdLoader._(
      id: id,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }
}
