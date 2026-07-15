/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.appopenad

import com.yandex.mobile.ads.appopenad.AppOpenAd
import com.yandex.mobile.ads.appopenad.AppOpenAdLoadListener
import com.yandex.mobile.ads.flutter.LoadListener
import com.yandex.mobile.ads.flutter.common.FullScreenAdCreator
import com.yandex.mobile.ads.flutter.util.ActivityContextHolder

internal class AppOpenAdLoadListener(private val adCreator: FullScreenAdCreator, private val activityContextHolder: ActivityContextHolder) : LoadListener(), AppOpenAdLoadListener {

    override fun onAdLoaded(ad: AppOpenAd) {
        val listener = AppOpenAdEventListener()
        ad.setAdEventListener(listener)
        val id = adCreator.createFullScreenAd(APP_OPEN_AD, listener) { AppOpenAdCommandHandlerProvider(ad, activityContextHolder, it) }
        respond(
            ON_AD_LOADED,
            mapOf(
                ID to id,
                AD_INFO to null
            )
        )
    }

    private companion object {
        const val APP_OPEN_AD = "appOpenAd"
    }
}
