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

final class AppOpenAdLoaderCommandProvider: CommandProvider {

    var commands: [Command] {
        [
            .command(.appOpenAdLoader(.load), loadAppOpenAd),
            .command(.appOpenAdLoader(.cancelLoading), cancelLoading),
            .command(.appOpenAdLoader(.destroy), destroyAppOpenAdLoader),
        ]
    }

    private let onDestroy: () -> Void
    private let adLoader: AppOpenAdLoader
    private var idCount = 0

    let name = "appOpenAdLoader"

    init(adLoader: AppOpenAdLoader, onDestroy: @escaping () -> Void) {
        self.adLoader = adLoader
        self.onDestroy = onDestroy
    }

    private func loadAppOpenAd(args: Any?, result: MethodCallResult) {
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

    private func destroyAppOpenAdLoader(args: Any?, result: MethodCallResult) {
        onDestroy()
        result.success()
    }
}
