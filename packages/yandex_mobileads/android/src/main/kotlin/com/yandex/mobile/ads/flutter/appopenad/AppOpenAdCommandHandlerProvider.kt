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
import com.yandex.mobile.ads.flutter.appopenad.command.DestroyAppOpenAdCommandHandler
import com.yandex.mobile.ads.flutter.appopenad.command.ShowAppOpenAdCommandHandler
import com.yandex.mobile.ads.flutter.common.CommandHandlerProvider
import com.yandex.mobile.ads.flutter.util.ActivityContextHolder

internal class AppOpenAdCommandHandlerProvider(
    ad: AppOpenAd,
    activityContextHolder: ActivityContextHolder,
    onDestroy: () -> Unit,
    adHolder: AppOpenAdHolder = AppOpenAdHolder(ad)
) : CommandHandlerProvider {

    override val name = PROVIDER_NAME
    override val commandHandlers = mapOf(
        SHOW to ShowAppOpenAdCommandHandler(activityContextHolder, adHolder),
        DESTROY to DestroyAppOpenAdCommandHandler(adHolder, onDestroy),
    )

    private companion object {

        const val PROVIDER_NAME = "appOpenAd"

        const val SHOW = "show"
        const val DESTROY = "destroy"
    }
}
