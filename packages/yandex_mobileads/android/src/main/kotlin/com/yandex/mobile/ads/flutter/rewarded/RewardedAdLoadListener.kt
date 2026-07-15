/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.rewarded

import com.yandex.mobile.ads.flutter.LoadListener
import com.yandex.mobile.ads.flutter.common.FullScreenAdCreator
import com.yandex.mobile.ads.flutter.interstitial.InterstitialAdLoadListener
import com.yandex.mobile.ads.flutter.util.ActivityContextHolder
import com.yandex.mobile.ads.flutter.util.toMap
import com.yandex.mobile.ads.rewarded.RewardedAd
import com.yandex.mobile.ads.rewarded.RewardedAdLoadListener

internal class RewardedAdLoadListener(private val adCreator: FullScreenAdCreator, private val activityContextHolder: ActivityContextHolder) : LoadListener(), RewardedAdLoadListener {

    override fun onAdLoaded(ad: RewardedAd) {
        val listener = RewardedAdEventListener()
        ad.setAdEventListener(listener)
        val id = adCreator.createFullScreenAd(REWARDED_AD, listener) { RewardedAdCommandHandlerProvider(ad, activityContextHolder, it) }
        respond(
            ON_AD_LOADED,
            mapOf(
                ID to id,
                AD_INFO to ad.info.toMap()
            )
        )
    }

    private companion object {
        const val REWARDED_AD = "rewardedAd"
    }
}
