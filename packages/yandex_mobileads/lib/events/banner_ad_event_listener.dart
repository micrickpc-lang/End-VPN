/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

part of '../mobile_ads.dart';

class _BannerAdEventListener {
  final String channelName;

  /// Notifies that the ad loaded successfully.
  final void Function()? onAdLoaded;

  /// Notifies that the ad failed to load.
  final void Function(AdRequestError error)? onAdFailedToLoad;

  /// Notifies that the user clicked on the ad.
  final void Function()? onAdClicked;

  /// Notifies that the app will run in the background now because the user clicked on the ad and is about to switch to a different app (Phone, App Store, and so on).
  final void Function()? onLeftApplication;

  /// Notifies that the user returned to app.
  final void Function()? onReturnedToApplication;

  /// Notifies that an ad impression has been counted.
  final void Function(ImpressionData impressionData)? onImpression;

  /// Notifies that the user has chosen a reason for closing the ad and the ad must be hidden
  final void Function()? onAdClose;

  late Stream eventStream;

  _BannerAdEventListener({
    required this.channelName,
    this.onAdLoaded,
    this.onAdFailedToLoad,
    this.onAdClicked,
    this.onLeftApplication,
    this.onReturnedToApplication,
    this.onImpression,
    this.onAdClose,
  });

  Future<void> setupCallbacks() async {
    eventStream = EventChannel(channelName).receiveBroadcastStream();
    await for (Map result in eventStream) {
      switch (_CallbackName.find(result['name'])) {
        case _CallbackName.onAdLoaded:
          onAdLoaded?.call();
          break;
        case _CallbackName.onAdFailedToLoad:
          onAdFailedToLoad?.call(AdRequestError(
              result['code'], result['description'], result['adUnitId']));
          break;
        case _CallbackName.onAdClicked:
          onAdClicked?.call();
          break;
        case _CallbackName.onLeftApplication:
          onLeftApplication?.call();
          break;
        case _CallbackName.onReturnedToApplication:
          onReturnedToApplication?.call();
          break;
        case _CallbackName.onImpression:
          onImpression?.call(
              _SimpleImpressionData(rawData: result['impressionData'] ?? ""));
          break;
        case _CallbackName.onAdClose:
          onAdClose?.call();
          break;
        default:
          break;
      }
    }
  }

  Future<Map> waitFor(List<_CallbackName> names) async {
    return await eventStream.firstWhere((result) {
      return names.any((name) => result['name'] == name.name);
    });
  }
}
