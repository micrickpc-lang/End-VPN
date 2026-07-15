/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

import YandexMobileAds

final class InterstitialAdViewController: BaseFullscreenAdViewController, InterstitialAdDelegate {
    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
        super.adDidFailToShow(error)
    }

    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
        fullScreenEvendDelegate.respond(.onAdShown)
    }

    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
        super.adDidDismiss()
    }

    func interstitialAdDidClick(_ ad: InterstitialAd) {
        fullScreenEvendDelegate.respond(.onAdClicked)
    }

    func interstitialAd(_ ad: InterstitialAd, didTrackImpressionWith impressionData: ImpressionData?) {
        fullScreenEvendDelegate.respond(.onAdImpression, ["impressionData": impressionData?.rawData])
    }
}
