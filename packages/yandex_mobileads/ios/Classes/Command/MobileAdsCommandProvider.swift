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

final class MobileAdsCommandProvider: CommandProvider {

    var commands: [Command] {
        [
            .command(.mobileAds(.initialize), initialize),
            .command(.mobileAds(.enableLogging), enableLogging),
            .command(.mobileAds(.enableDebugErrorIndicator), enableDebugErrorIndicator),
            .command(.mobileAds(.showDebugPanel), showDebugPanel),
            .command(.mobileAds(.setLocationConsent), setLocationConsent),
            .command(.mobileAds(.setUserConsent), setUserConsent),
            .command(.mobileAds(.setAgeRestrictedUser), setAgeRestrictedUser),
        ]
    }

    let name = "mobileAds"

    private func initialize(args: Any?, result: MethodCallResult) {
        MobileAds.initializeSDK {
            result.success()
        }
    }

    private func enableLogging(args: Any?, result: MethodCallResult) {
        MobileAds.enableLogging()
        result.success()
    }

    private func enableDebugErrorIndicator(args: Any?, result: MethodCallResult) {
        MobileAds.enableVisibilityErrorIndicator(for: .hardware)
        MobileAds.enableVisibilityErrorIndicator(for: .simulator)
        result.success()
    }

    private func showDebugPanel(args: Any?, result: MethodCallResult) {
        MobileAds.showDebugPanel()
        result.success()
    }

    private func setLocationConsent(args: Any?, result: MethodCallResult) {
        guard let value = args as? Bool else {
            return result.error(.argsIsNotBool)
        }
        MobileAds.setLocationTrackingEnabled(value)
        result.success()
    }

    private func setUserConsent(args: Any?, result: MethodCallResult) {
        guard let value = args as? Bool else {
            return result.error(.argsIsNotBool)
        }
        MobileAds.setUserConsent(value)
        result.success()
    }

    private func setAgeRestrictedUser(args: Any?, result: MethodCallResult) {
        guard let value = args as? Bool else {
            return result.error(.argsIsNotBool)
        }
        MobileAds.setAgeRestrictedUser(value)
        result.success()
    }
}
