/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

import YandexMobileAds

final class AppOpenAdLoadDelegate: LoadDelegate, AppOpenAdLoaderDelegate {

    private let adCreator: FullScreenAdCreator

    init(adCreator: FullScreenAdCreator) {
        self.adCreator = adCreator
    }

    func appOpenAdLoader(_ adLoader: AppOpenAdLoader, didLoad appOpenAd: AppOpenAd) {
        let id = adCreator.createAppOpenAd(ad: appOpenAd)
        respond(.onAdLoaded, ["id" : id, "adInfo" : adInfoToMap(adInfo:appOpenAd.adInfo)])
    }

    func appOpenAdLoader(_ adLoader: AppOpenAdLoader, didFailToLoadWithError error: AdRequestError) {
        let errorMap = error.error.toMap()
        respond(.onAdFailedToLoad, ["adUnitId": error.adUnitId, "code": errorMap["code"] ?? 1, "description": errorMap["description"] ?? ""])
    }
}
