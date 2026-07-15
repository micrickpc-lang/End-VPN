/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.appopenad

import com.yandex.mobile.ads.appopenad.AppOpenAdLoader
import com.yandex.mobile.ads.flutter.appopenad.command.CancelLoadingAppOpenAdCommandHandler
import com.yandex.mobile.ads.flutter.appopenad.command.DestroyAppOpenAdLoaderCommandHandler
import com.yandex.mobile.ads.flutter.appopenad.command.LoadAppOpenAdCommandHandler
import com.yandex.mobile.ads.flutter.common.CommandHandlerProvider

internal class AppOpenAdLoaderCommandHandlerProvider(
    loader: AppOpenAdLoader,
    onDestroy: () -> Unit,
    loaderHolder: AppOpenAdLoaderHolder = AppOpenAdLoaderHolder(loader)
) : CommandHandlerProvider {

    override val name = PROVIDER_NAME
    override val commandHandlers = mapOf(
        LOAD to LoadAppOpenAdCommandHandler(loaderHolder),
        CANCEL_LOADING to CancelLoadingAppOpenAdCommandHandler(loaderHolder),
        DESTROY to DestroyAppOpenAdLoaderCommandHandler(loaderHolder, onDestroy)
    )

    private companion object {

        const val PROVIDER_NAME = "appOpenAdLoader"

        const val LOAD = "load"
        const val CANCEL_LOADING = "cancelLoading"
        const val DESTROY = "destroy"
    }
}
