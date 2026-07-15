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

final class BannerAdEventDelegate: EventDelegate, AdViewDelegate {

    func adViewDidLoad(_ adView: AdView) {
        let width = Int(adView.adContentSize().width)
        let height = Int(adView.adContentSize().height)
        respond(.onAdLoaded, ["width": width, "height": height])
    }

    func adViewDidFailLoading(_ adView: AdView, error: Error) {
        respond(.onAdFailedToLoad, error.toMap())
    }

    func adViewDidClick(_ adView: AdView) {
        respond(.onAdClicked)
    }

    func adViewWillLeaveApplication(_ adView: AdView) {
        respond(.onLeftApplication)
    }

    func adView(_ adView: AdView, didTrackImpression impressionData: ImpressionData?) {
        respond(.onImpression, ["impressionData": impressionData?.rawData])
    }
    
    func close(_ adView: YandexMobileAds.AdView) {
        respond(.onAdClose)
    }
}
