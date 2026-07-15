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
import com.yandex.mobile.ads.flutter.interstitial.command.CancelLoadingInterstitialAdCommandHandler
import com.yandex.mobile.ads.flutter.interstitial.command.DestroyInterstitialAdLoaderCommandHandler
import com.yandex.mobile.ads.flutter.interstitial.command.LoadInterstitialAdCommandHandler
import com.yandex.mobile.ads.interstitial.InterstitialAdLoader

internal class InterstitialAdLoaderCommandHandlerProvider(
    loader: InterstitialAdLoader,
    onDestroy: () -> Unit,
    loaderHolder: InterstitialAdLoaderHolder = InterstitialAdLoaderHolder(loader)
) : CommandHandlerProvider {

    override val name = PROVIDER_NAME
    override val commandHandlers = mapOf(
        LOAD to LoadInterstitialAdCommandHandler(loaderHolder),
        CANCEL_LOADING to CancelLoadingInterstitialAdCommandHandler(loaderHolder),
        DESTROY to DestroyInterstitialAdLoaderCommandHandler(loaderHolder, onDestroy)
    )

    private companion object {

        const val PROVIDER_NAME = "interstitialAdLoader"

        const val LOAD = "load"
        const val CANCEL_LOADING = "cancelLoading"
        const val DESTROY = "destroy"
    }
}
