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

final class InterstitialAdLoaderCommandProvider: CommandProvider {

    var commands: [Command] {
        [
            .command(.interstitialAdLoader(.load), loadInterstitialAd),
            .command(.interstitialAdLoader(.cancelLoading), cancelLoading),
            .command(.interstitialAdLoader(.destroy), destroyInterstitialAdLoader),
        ]
    }

    private let onDestroy: () -> Void
    private let adLoader: InterstitialAdLoader
    private var idCount = 0

    let name = "interstitialAdLoader"

    init(adLoader: InterstitialAdLoader, onDestroy: @escaping () -> Void) {
        self.adLoader = adLoader
        self.onDestroy = onDestroy
    }

    private func loadInterstitialAd(args: Any?, result: MethodCallResult) {
        guard let args = args as? [String: Any?] else {
            return result.error(.argsIsNotMap)
        }
        let adUnitID = args["adUnitId"] as? String ?? ""
        adLoader.loadAd(with: args.toAdRequestConfiguration(adUnitID: adUnitID))
        result.success()
    }

    private func cancelLoading(args: Any?, result: MethodCallResult) {
        adLoader.cancelLoading()
        result.success()
    }

    private func destroyInterstitialAdLoader(args: Any?, result: MethodCallResult) {
        onDestroy()
        result.success()
    }
}
