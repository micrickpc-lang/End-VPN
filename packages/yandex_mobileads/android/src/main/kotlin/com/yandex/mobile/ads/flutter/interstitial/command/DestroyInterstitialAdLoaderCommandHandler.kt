/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.interstitial.command

import com.yandex.mobile.ads.flutter.common.CommandHandler
import com.yandex.mobile.ads.flutter.interstitial.InterstitialAdLoaderHolder
import com.yandex.mobile.ads.flutter.util.success
import io.flutter.plugin.common.MethodChannel.Result

internal class DestroyInterstitialAdLoaderCommandHandler(
    private val adLoaderHolder: InterstitialAdLoaderHolder,
    private val onDestroy: () -> Unit,
) : CommandHandler {

    override fun handleCommand(command: String, args: Any?, result: Result) {
        adLoaderHolder.loader?.cancelLoading()
        adLoaderHolder.loader?.setAdLoadListener(null)
        adLoaderHolder.loader = null
        onDestroy()
        result.success()
    }
}
