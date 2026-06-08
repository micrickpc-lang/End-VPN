import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  static const _adUnitId = 'R-M-19350284-1';

  RewardedAd? _rewardedAd;
  RewardedAdLoader? _adLoader;
  bool _isLoaded = false;

  Future<void> init() async {
    await MobileAds.initialize();
    await _createLoader();
    await _loadAd();
  }

  Future<void> _createLoader() async {
    _adLoader = await RewardedAdLoader.create(
      onAdLoaded: (RewardedAd ad) {
        _rewardedAd = ad;
        _isLoaded = true;
      },
      onAdFailedToLoad: (AdRequestError error) {
        debugPrint('Ad failed to load: $error');
        _rewardedAd = null;
        _isLoaded = false;
      },
    );
  }

  Future<void> _loadAd() async {
    await _adLoader?.loadAd(
      adRequestConfiguration: const AdRequestConfiguration(
        adUnitId: _adUnitId,
      ),
    );
  }

  Future<bool> showRewardedAd(BuildContext context) async {
    if (!_isLoaded || _rewardedAd == null) {
      _loadAd();
      return true;
    }

    final completer = Completer<bool>();

    _rewardedAd!.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onAdShown: () {},
        onAdDismissed: () {
          if (!completer.isCompleted) completer.complete(false);
          _isLoaded = false;
          _rewardedAd = null;
          _loadAd();
        },
        onAdFailedToShow: (AdError error) {
          if (!completer.isCompleted) completer.complete(true);
          _isLoaded = false;
          _rewardedAd = null;
          _loadAd();
        },
        onAdClicked: () {},
        onAdImpression: (ImpressionData? data) {},
        onRewarded: (Reward reward) {
          if (!completer.isCompleted) completer.complete(true);
        },
      ),
    );

    try {
      await _rewardedAd!.show();
    } catch (e) {
      debugPrint('Ad show error: $e');
      if (!completer.isCompleted) completer.complete(true);
    }

    return completer.future;
  }

  bool get isLoaded => _isLoaded;
}