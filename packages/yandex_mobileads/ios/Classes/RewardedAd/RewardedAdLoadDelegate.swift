/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

import YandexMobileAds

final class RewardedAdLoadDelegate: LoadDelegate, RewardedAdLoaderDelegate {

    private let adCreator: FullScreenAdCreator

    init(adCreator: FullScreenAdCreator) {
        self.adCreator = adCreator
    }

    func rewardedAdLoader(_ adLoader: RewardedAdLoader, didLoad rewardedAd: RewardedAd) {
        let id = adCreator.createRewardedAd(ad: rewardedAd)
        respond(.onAdLoaded, ["id" : id, "adInfo" : adInfoToMap(adInfo: rewardedAd.adInfo)])
    }

    func rewardedAdLoader(_ adLoader: RewardedAdLoader, didFailToLoadWithError error: AdRequestError) {
        let errorMap = error.error.toMap()
        respond(.onAdFailedToLoad, ["adUnitId": error.adUnitId, "code": errorMap["code"] ?? 1, "description": errorMap["description"] ?? ""])
    }
}
