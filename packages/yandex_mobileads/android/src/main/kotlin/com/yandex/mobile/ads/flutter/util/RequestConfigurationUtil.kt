/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

package com.yandex.mobile.ads.flutter.util

import com.yandex.mobile.ads.common.AdRequestConfiguration

internal fun Map<String, Any?>.toAdRequestConfiguration(adUnitId: String) = AdRequestConfiguration.Builder(adUnitId).also { adRequestConfigurationBuilder ->
    (getValueOrNull<String>(AGE))?.let(adRequestConfigurationBuilder::setAge)
    (getValueOrNull<String>(CONTEXT_QUERY))?.let(adRequestConfigurationBuilder::setContextQuery)
    (getValueOrNull<List<String>>(CONTEXT_TAGS))?.let(adRequestConfigurationBuilder::setContextTags)
    (getValueOrNull<String>(GENDER))?.let(adRequestConfigurationBuilder::setGender)
    (getValueOrNull<Map<String, Double>>(LOCATION))?.toLocation()?.let(adRequestConfigurationBuilder::setLocation)
    (getValueOrNull<Map<String, String>>(PARAMETERS))?.let(adRequestConfigurationBuilder::setParameters)
    (getValueOrNull<String>(PREFERRED_THEME))?.toAdTheme()?.let(adRequestConfigurationBuilder::setPreferredTheme)
}.build()

private const val AGE = "age"
private const val CONTEXT_QUERY = "contextQuery"
private const val CONTEXT_TAGS = "contextTags"
private const val GENDER = "gender"
private const val LOCATION = "location"
private const val PARAMETERS = "parameters"
private const val PREFERRED_THEME = "preferredTheme"
