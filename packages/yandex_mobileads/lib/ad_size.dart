/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

part of 'mobile_ads.dart';

/// An AdSize contains the size of a fullscreen ad.
class AdSize {
  const AdSize({required this.width, required this.height});

  /// Width in density-independent pixels (dp).
  final double? width;

  /// Height in density-independent pixels (dp).
  final double? height;

  static AdSize? _fromMap(Map map) {
    try {
      final adSizeMap = ((map['adInfo'] as Map?)?['adSize'] as Map?);
      if (adSizeMap != null) {
        return AdSize(
            width: double.tryParse(adSizeMap['width'].toString()),
            height: double.tryParse(adSizeMap['height'].toString()));
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }
}
