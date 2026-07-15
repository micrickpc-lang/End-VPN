/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.util

import android.location.Location
import com.yandex.mobile.ads.common.AdRequest

internal fun Map<String, Any?>.toAdRequest() = AdRequest.Builder().also { adRequestBuilder ->
    (getValueOrNull<String>(AGE))?.let(adRequestBuilder::setAge)
    (getValueOrNull<String>(CONTEXT_QUERY))?.let(adRequestBuilder::setContextQuery)
    (getValueOrNull<List<String>>(CONTEXT_TAGS))?.let(adRequestBuilder::setContextTags)
    (getValueOrNull<String>(GENDER))?.let(adRequestBuilder::setGender)
    (getValueOrNull<Map<String, Double>>(LOCATION))?.toLocation()?.let(adRequestBuilder::setLocation)
    (getValueOrNull<Map<String, String>>(PARAMETERS))?.let(adRequestBuilder::setParameters)
    (getValueOrNull<String>(PREFERRED_THEME))?.toAdTheme()?.let(adRequestBuilder::setPreferredTheme)
}.build()

private const val AGE = "age"
private const val CONTEXT_QUERY = "contextQuery"
private const val CONTEXT_TAGS = "contextTags"
private const val GENDER = "gender"
private const val LOCATION = "location"
private const val PARAMETERS = "parameters"
private const val PREFERRED_THEME = "preferredTheme"
