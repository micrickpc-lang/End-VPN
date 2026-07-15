/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

part of '../mobile_ads.dart';

class _RewardedAdLoadListener {
  final String channelName;

  /// Notifies that the ad loaded successfully.
  final void Function(RewardedAd rewardedAd)? onAdLoaded;

  /// Notifies that the ad failed to load.
  final void Function(AdRequestError error)? onAdFailedToLoad;

  late Stream eventStream;

  _RewardedAdLoadListener({
    required this.channelName,
    this.onAdLoaded,
    this.onAdFailedToLoad,
  });

  Future<void> setupCallbacks() async {
    eventStream = EventChannel(channelName).receiveBroadcastStream();
    await for (Map result in eventStream) {
      switch (_FullScreenAdCallbackName.find(result['name'])) {
        case _FullScreenAdCallbackName.onAdLoaded:
          onAdLoaded?.call(RewardedAd._create(
              id: result['id'], adInfo: AdInfo._fromMap(result)));
          break;
        case _FullScreenAdCallbackName.onAdFailedToLoad:
          onAdFailedToLoad?.call(AdRequestError(
              result['code'], result['description'], result['adUnitId']));
          break;
        default:
          break;
      }
    }
  }

  Future<Map> waitFor(List<_FullScreenAdCallbackName> names) async {
    return await eventStream.firstWhere((result) {
      return names.any((name) => result['name'] == name.name);
    });
  }
}
