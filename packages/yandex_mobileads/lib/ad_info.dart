/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

part of 'mobile_ads.dart';

/// An AdInfo contains information about ad size and unit id.
class AdInfo {
  final String adUnitId;

  final AdSize? adSize;

  const AdInfo({required this.adUnitId, this.adSize});

  static AdInfo _fromMap(Map map) {
    try {
      final adUnitId = ((map['adInfo'] as Map?)?['adUnitId'] as String?) ?? "";
      final adSize = AdSize._fromMap(map);
      return AdInfo(adUnitId: adUnitId, adSize: adSize);
    } catch (_) {
      return const AdInfo(adUnitId: "", adSize: null);
    }
  }
}
