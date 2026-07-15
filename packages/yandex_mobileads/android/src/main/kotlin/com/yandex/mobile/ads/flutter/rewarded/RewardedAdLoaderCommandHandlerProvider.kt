/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.rewarded

import com.yandex.mobile.ads.flutter.common.CommandHandlerProvider
import com.yandex.mobile.ads.flutter.rewarded.command.CancelLoadingRewardedAdCommandHandler
import com.yandex.mobile.ads.flutter.rewarded.command.DestroyRewardedAdLoaderCommandHandler
import com.yandex.mobile.ads.flutter.rewarded.command.LoadRewardedAdCommandHandler
import com.yandex.mobile.ads.rewarded.RewardedAdLoader

internal class RewardedAdLoaderCommandHandlerProvider(
    loader: RewardedAdLoader,
    onDestroy: () -> Unit,
    loaderHolder: RewardedAdLoaderHolder = RewardedAdLoaderHolder(loader)
) : CommandHandlerProvider {

    override val name = PROVIDER_NAME
    override val commandHandlers = mapOf(
        LOAD to LoadRewardedAdCommandHandler(loaderHolder),
        CANCEL_LOADING to CancelLoadingRewardedAdCommandHandler(loaderHolder),
        DESTROY to DestroyRewardedAdLoaderCommandHandler(loaderHolder, onDestroy)
    )

    private companion object {

        const val PROVIDER_NAME = "rewardedAdLoader"

        const val LOAD = "load"
        const val CANCEL_LOADING = "cancelLoading"
        const val DESTROY = "destroy"
    }
}
