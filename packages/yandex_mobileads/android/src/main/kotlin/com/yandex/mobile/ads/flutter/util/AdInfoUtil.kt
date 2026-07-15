/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.util

import com.yandex.mobile.ads.common.AdInfo

internal fun AdInfo.toMap(): Map<String, Any?> {
    return mapOf(
        AD_UNIT_ID to this.adUnitId,
        AD_SIZE to this.adSize?.run { mapOf(WIDTH to width, HEIGHT to height) }
    )
}

private const val WIDTH = "width"
private const val HEIGHT = "height"
private const val AD_UNIT_ID = "adUnitId"
private const val AD_SIZE = "adSize"
