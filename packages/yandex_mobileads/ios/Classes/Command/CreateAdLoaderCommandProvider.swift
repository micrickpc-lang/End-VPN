/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

import Flutter
import YandexMobileAds

final class CreateAdLoaderCommandProvider: CommandProvider {

    let messenger: FlutterBinaryMessenger
    var commands: [Command] {
        [
            .command(.createAdLoader(.interstitialAdLoader), createInterstitialAdLoader),
            .command(.createAdLoader(.rewardedAdLoader), createRewardedAdLoader),
            .command(.createAdLoader(.appOpenAdLoader), createAppOpenAdLoader),
        ]
    }

    private var idCount = 0

    let name = "createAdLoader"

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    private func createAppOpenAdLoader(args: Any?, result: MethodCallResult) {
        let adLoader = AppOpenAdLoader()
        let adCreator = FullScreenAdCreator(messenger: messenger)
        let delegate = AppOpenAdLoadDelegate(adCreator: adCreator)
        adLoader.delegate = delegate
        createAdLoader(result: result, channelName: appOpenAdLoaderChannelName,
                       delegate: delegate)
        {
            AppOpenAdLoaderCommandProvider(adLoader: adLoader, onDestroy: $0)
        }
    }

    private func createInterstitialAdLoader(args: Any?, result: MethodCallResult) {
        let adLoader = InterstitialAdLoader()
        let adCreator = FullScreenAdCreator(messenger: messenger)
        let delegate = InterstititalAdLoadDelegate(adCreator: adCreator)
        adLoader.delegate = delegate
        createAdLoader(result: result, channelName: interstitialAdLoaderChannelName, delegate: delegate) {
            InterstitialAdLoaderCommandProvider(adLoader: adLoader, onDestroy: $0)
        }
    }

    private func createRewardedAdLoader(args: Any?, result: MethodCallResult) {
        let adLoader = RewardedAdLoader()
        let adCreator = FullScreenAdCreator(messenger: messenger)
        let delegate = RewardedAdLoadDelegate(adCreator: adCreator)
        adLoader.delegate = delegate
        createAdLoader(result: result, channelName: rewardedAdLoaderChannelName, delegate: delegate) {
            RewardedAdLoaderCommandProvider(adLoader: adLoader, onDestroy: $0)
        }
    }

    private func createAdLoader(
        result: MethodCallResult,
        channelName: String,
        delegate: LoadDelegate,
        providerFactory: (_ onDestroy: @escaping () -> Void) -> CommandProvider
    ) {
        let id = idCount
        idCount += 1
        let name = "\(YandexMobileAdsPlugin.channelName).\(channelName).\(id)"
        let methodChannel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        let eventChannel = FlutterEventChannel(name: "\(name).events", binaryMessenger: messenger)
        let provider = providerFactory {
            methodChannel.setMethodCallHandler(nil)
            eventChannel.setStreamHandler(nil)
        }
        methodChannel.setMethodCallHandler(provider.callHandler)
        eventChannel.setStreamHandler(delegate)
        result.success(id)
    }

    private let appOpenAdLoaderChannelName = "appOpenAdLoader"
    private let interstitialAdLoaderChannelName = "interstitialAdLoader"
    private let rewardedAdLoaderChannelName = "rewardedAdLoader"
}
