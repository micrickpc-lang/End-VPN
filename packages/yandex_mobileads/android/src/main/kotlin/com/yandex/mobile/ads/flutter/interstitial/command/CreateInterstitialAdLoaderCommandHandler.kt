/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.interstitial.command

import com.yandex.mobile.ads.flutter.common.AdLoaderCreator
import com.yandex.mobile.ads.flutter.common.CommandHandler
import com.yandex.mobile.ads.flutter.common.FullScreenAdCreator
import com.yandex.mobile.ads.flutter.interstitial.InterstitialAdLoadListener
import com.yandex.mobile.ads.flutter.interstitial.InterstitialAdLoaderCommandHandlerProvider
import com.yandex.mobile.ads.flutter.util.ActivityContextHolder
import com.yandex.mobile.ads.interstitial.InterstitialAdLoader
import io.flutter.plugin.common.MethodChannel.Result

internal class CreateInterstitialAdLoaderCommandHandler(
    private val activityContextHolder: ActivityContextHolder,
    private val adLoaderCreator: AdLoaderCreator,
    private val adCreator: FullScreenAdCreator
) : CommandHandler {

    override fun handleCommand(command: String, args: Any?, result: Result) {
        val context = activityContextHolder.activityContext?.applicationContext ?: return
        val loader = InterstitialAdLoader(context)
        val listener = InterstitialAdLoadListener(adCreator, activityContextHolder)
        loader.setAdLoadListener(listener)
        adLoaderCreator.createAdLoader(result, INTERSTITIAL_AD_LOADER, listener) {
            InterstitialAdLoaderCommandHandlerProvider(loader, it)
        }
    }

    private companion object {

        const val INTERSTITIAL_AD_LOADER = "interstitialAdLoader"
    }
}
