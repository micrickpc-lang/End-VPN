/*
 * This file is a part of the Yandex Advertising Network
 *
 * Version for Flutter (C) 2023 YANDEX
 *
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at https://legal.yandex.com/partner_ch/
 */

part of 'mobile_ads.dart';

/// An AdRequest contains targeting information used to fetch an ad.
class AdRequest {
  /// User's age.
  final int? age;

  /// Context query entered inside the app.
  final String? contextQuery;

  /// Context tags describing current user context inside the app.
  final List<String>? contextTags;

  /// User's gender.
  final String? gender;

  /// User's location.
  final AdLocation? location;

  /// Custom parameters for ad loading request.
  final Map<String, String>? parameters;

  /// Preferred ad theme.
  final AdTheme? preferredTheme;

  const AdRequest(
      {this.age,
      this.contextQuery,
      this.contextTags,
      this.gender,
      this.location,
      this.parameters,
      this.preferredTheme});

  Map<String, dynamic> _toMap() => {
        'age': age.toString(),
        'contextQuery': contextQuery,
        'contextTags': contextTags,
        'gender': gender,
        'location': location?._toMap(),
        'parameters': parameters,
        'preferredTheme': preferredTheme?.name,
      };
}
