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

final class AppOpenAdCommandProvider: CommandProvider {
    var commands: [Command] {
        [
            .command(.appOpenAd(.show), showAppOpenAd),
            .command(.appOpenAd(.destroy), destroyAppOpenAd),
        ]
    }

    private let onDestroy: () -> Void
    private let ad: AppOpenAd
    private var idCount = 0
    private let appOpenAdViewController: AppOpenAdViewController

    let name = "appOpenAd"

    init(
        ad: AppOpenAd,
        onDestroy: @escaping () -> Void,
        appOpenAdViewController: AppOpenAdViewController
    ) {
        self.ad = ad
        self.onDestroy = onDestroy
        self.appOpenAdViewController = appOpenAdViewController
    }

    private func showAppOpenAd(args: Any?, result: MethodCallResult) {
        guard let controller = Self.controller else {
            return result.error(.noViewController)
        }
        controller.present(appOpenAdViewController, animated: false) { [weak self] in
            guard let self else { return }
            self.ad.show(from: self.appOpenAdViewController)
            result.success()
        }
    }

    private func destroyAppOpenAd(args: Any?, result: MethodCallResult) {
        onDestroy()
        result.success()
    }
}
