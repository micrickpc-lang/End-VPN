/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

part of '../mobile_ads.dart';

/// This class is responsible for loading and showing a banner ad.
class BannerAd with _Ad {
  static const _channelPath = 'yandex_mobileads.bannerAd';
  static var _idCount = 0;

  static const _pluginType = 'plugin_type';
  static const _pluginVersion = 'plugin_version';
  static const _flutter = 'flutter';

  final BannerAdSize adSize;
  final AdRequest? adRequest;
  final int _id = _idCount++;

  late final String _adUnitId;
  late final _BannerAdEventListener _eventListener;

  @override
  String get methodChannelName => '$_channelPath.$_id';

  late final Widget _widget = _PlatformInterface.instance.buildBannerAd(
      adUnitId: _adUnitId,
      adSize: adSize,
      id: _id,
      onPlatformViewCreated: (_) async {
        _eventListener.setupCallbacks();
        loadAd(adRequest: adRequest);
        final result = await _eventListener.waitFor([_CallbackName.onAdLoaded]);
        _onAdLoaded?.call(result['width'], result['height']);
      });

  Future<void> loadAd({AdRequest? adRequest}) async {
    final map = adRequest?._toMap() ?? {};
    map['parameters'] = {
      _pluginType: _flutter,
      _pluginVersion: MobileAds.pluginVersion,
    }..addAll(adRequest?.parameters ?? {});
    _channel.invokeMethod('load', map);
  }

  void Function(int width, int height)? _onAdLoaded;

  BannerAd({
    required String adUnitId,
    required this.adSize,
    this.adRequest,
    void Function()? onAdLoaded,
    void Function(AdRequestError error)? onAdFailedToLoad,
    void Function()? onAdClicked,
    void Function()? onLeftApplication,
    void Function()? onReturnedToApplication,
    void Function(ImpressionData impressionData)? onImpression,
    void Function()? onAdClose,
  }) : _adUnitId = adUnitId {
    _eventListener = _BannerAdEventListener(
      channelName: '$_channelPath.$_id.events',
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
      onAdClicked: onAdClicked,
      onLeftApplication: onLeftApplication,
      onReturnedToApplication: onReturnedToApplication,
      onImpression: onImpression,
      onAdClose: onAdClose,
    );
  }
}

class AdWidget extends StatefulWidget {
  final BannerAd bannerAd;

  const AdWidget({
    super.key,
    required this.bannerAd,
  });

  @override
  State<AdWidget> createState() => _AdWidgetState();
}

class _AdWidgetState extends State<AdWidget> {
  late int width, height;

  @override
  void initState() {
    super.initState();
    width = widget.bannerAd.adSize.width;
    height = BannerAdSize._initialHeight;
    widget.bannerAd._onAdLoaded = (width, height) {
      if (mounted) {
        setState(() {
          this.width = width;
          this.height = height;
        });
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey(widget.bannerAd._id),
      width: width.toDouble(),
      height: height.toDouble(),
      child: widget.bannerAd._widget,
    );
  }
}
