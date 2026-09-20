import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import 'ad_load_gate.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  static const _adUnitId = 'R-M-19350284-1';
  static const _loadTimeout = Duration(seconds: 20);

  RewardedAd? _rewardedAd;
  RewardedAdLoader? _adLoader;
  Future<void>? _initFuture;
  final AdLoadGate _loadGate = AdLoadGate();
  String? _lastLoadError;

  Future<void> init() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await (_initFuture ??= _initialize());
    } catch (_) {
      // A transient SDK failure must not permanently disable later attempts.
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    await MobileAds.initialize();
    await _createLoader();
    unawaited(_loadAd());
  }

  Future<void> _createLoader() async {
    _adLoader = await RewardedAdLoader.create(
      onAdLoaded: (RewardedAd ad) {
        _rewardedAd = ad;
        _lastLoadError = null;
        _loadGate.loaded();
      },
      onAdFailedToLoad: (AdRequestError error) {
        debugPrint('Ad failed to load: $error');
        _lastLoadError = 'код ${error.code}: ${error.description}';
        _loadGate.failed();
      },
    );
  }

  Future<bool> _loadAd() {
    if (_rewardedAd != null) return Future.value(true);
    return _requestAd();
  }

  Future<bool> _requestAd() async {
    final loader = _adLoader;
    if (loader == null) return false;

    try {
      return await _loadGate.request(
        start: () => loader.loadAd(
          adRequestConfiguration: const AdRequestConfiguration(
            adUnitId: _adUnitId,
          ),
        ),
        timeout: _loadTimeout,
        onTimeout: () async {
          debugPrint('Ad load timed out');
          _lastLoadError = 'истекло время ожидания';
          try {
            await loader.cancelLoading().timeout(const Duration(seconds: 2));
          } catch (error) {
            debugPrint('Ad cancel error: $error');
          }
        },
      );
    } catch (error) {
      debugPrint('Ad load error: $error');
      _lastLoadError = error.toString();
      return false;
    }
  }

  Future<bool> showRewardedAd(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    try {
      await init();
      if (_rewardedAd == null) await _loadAd();
    } catch (error) {
      debugPrint('Ad initialization error: $error');
      _lastLoadError = error.toString();
    }
    final ad = _rewardedAd;
    if (ad == null) {
      if (context.mounted) {
        final reason = _lastLoadError;
        final message = reason == null
            ? 'Реклама пока не загрузилась. Попробуйте ещё раз.'
            : 'Реклама не загрузилась ($reason). Попробуйте ещё раз.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    }

    final completer = Completer<bool>();
    var earnedReward = false;
    var released = false;
    void releaseAd() {
      if (released) return;
      released = true;
      if (identical(_rewardedAd, ad)) _rewardedAd = null;
      unawaited(_disposeAndReload(ad));
    }

    try {
      await ad.setAdEventListener(
        eventListener: RewardedAdEventListener(
          onAdShown: () {},
          onAdDismissed: () {
            if (!completer.isCompleted) completer.complete(earnedReward);
            releaseAd();
          },
          onAdFailedToShow: (AdError error) {
            debugPrint('Ad failed to show: $error');
            if (!completer.isCompleted) completer.complete(false);
            releaseAd();
          },
          onAdClicked: () {},
          onAdImpression: (ImpressionData? data) {},
          onRewarded: (Reward reward) {
            earnedReward = true;
          },
        ),
      );
      await ad.show();
    } catch (e) {
      debugPrint('Ad show error: $e');
      if (!completer.isCompleted) completer.complete(false);
      releaseAd();
    }

    return completer.future;
  }

  Future<void> _disposeAndReload(RewardedAd ad) async {
    try {
      await ad.destroy();
    } catch (error) {
      debugPrint('Ad destroy error: $error');
    }
    if (_rewardedAd == null) await _loadAd();
  }

  bool get isLoaded => _rewardedAd != null;
}
