/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.rewarded.command

import com.yandex.mobile.ads.flutter.common.AdLoaderCreator
import com.yandex.mobile.ads.flutter.common.CommandHandler
import com.yandex.mobile.ads.flutter.common.FullScreenAdCreator
import com.yandex.mobile.ads.flutter.rewarded.RewardedAdLoadListener
import com.yandex.mobile.ads.flutter.rewarded.RewardedAdLoaderCommandHandlerProvider
import com.yandex.mobile.ads.flutter.util.ActivityContextHolder
import com.yandex.mobile.ads.rewarded.RewardedAdLoader
import io.flutter.plugin.common.MethodChannel.Result

internal class CreateRewardedAdLoaderCommandHandler(
    private val activityContextHolder: ActivityContextHolder,
    private val adLoaderCreator: AdLoaderCreator,
    private val adCreator: FullScreenAdCreator,
) : CommandHandler {

    override fun handleCommand(command: String, args: Any?, result: Result) {
        val context = activityContextHolder.activityContext?.applicationContext ?: return

        val loader = RewardedAdLoader(context)
        val listener = RewardedAdLoadListener(adCreator, activityContextHolder)
        loader.setAdLoadListener(listener)
        adLoaderCreator.createAdLoader(result, REWARDED_AD_LOADER, listener) {
            RewardedAdLoaderCommandHandlerProvider(loader, it)
        }
    }

    private companion object {

        const val REWARDED_AD_LOADER = "rewardedAdLoader"
    }
}
