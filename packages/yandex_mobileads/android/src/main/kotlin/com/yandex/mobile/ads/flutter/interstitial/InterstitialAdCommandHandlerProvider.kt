/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.interstitial

import com.yandex.mobile.ads.flutter.common.CommandHandlerProvider
import com.yandex.mobile.ads.flutter.interstitial.command.DestroyInterstitialAdCommandHandler
import com.yandex.mobile.ads.flutter.interstitial.command.ShowInterstitialAdCommandHandler
import com.yandex.mobile.ads.flutter.util.ActivityContextHolder
import com.yandex.mobile.ads.interstitial.InterstitialAd

internal class InterstitialAdCommandHandlerProvider(
    ad: InterstitialAd,
    activityContextHolder: ActivityContextHolder,
    onDestroy: () -> Unit,
    adHolder: InterstitialAdHolder = InterstitialAdHolder(ad)
) : CommandHandlerProvider {

    override val name = PROVIDER_NAME
    override val commandHandlers = mapOf(
        SHOW to ShowInterstitialAdCommandHandler(activityContextHolder, adHolder),
        DESTROY to DestroyInterstitialAdCommandHandler(adHolder, onDestroy),
    )

    private companion object {

        const val PROVIDER_NAME = "interstitialAd"

        const val SHOW = "show"
        const val DESTROY = "destroy"
    }
}
