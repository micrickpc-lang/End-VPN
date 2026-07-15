/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.rewarded.command

import com.yandex.mobile.ads.flutter.common.CommandError
import com.yandex.mobile.ads.flutter.common.CommandHandler
import com.yandex.mobile.ads.flutter.rewarded.RewardedAdLoaderHolder
import com.yandex.mobile.ads.flutter.util.error
import com.yandex.mobile.ads.flutter.util.success
import com.yandex.mobile.ads.flutter.util.toAdRequestConfiguration
import io.flutter.plugin.common.MethodChannel.Result

internal class LoadRewardedAdCommandHandler(
    private val loaderHolder: RewardedAdLoaderHolder
) : CommandHandler {

    override fun handleCommand(command: String, args: Any?, result: Result) {
        val args = args as? Map<String, Any?>
            ?: return result.error(CommandError.MissingArgsCast)
        val adUnitId = args[AD_UNIT_ID] as? String? ?: ""
        val loader = loaderHolder.loader ?: return result.error(CommandError.RewardedAdLoaderIsNull)
        loader.loadAd(args.toAdRequestConfiguration(adUnitId))
        result.success()
    }

    companion object {
        private const val AD_UNIT_ID = "adUnitId"
    }
}
