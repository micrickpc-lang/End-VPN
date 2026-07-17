import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endvpn/core/config/app_config.dart';

void main() {
  test('payment API paths resolve behind the nginx payment prefix', () {
    final create = RequestOptions(
      baseUrl: AppConfig.botApiUrl,
      path: '/create',
    ).uri;
    final check = RequestOptions(
      baseUrl: AppConfig.botApiUrl,
      path: '/check',
    ).uri;

    expect(create.toString(), 'https://panel.kaban4ik.ru/payment/create');
    expect(check.toString(), 'https://panel.kaban4ik.ru/payment/check');
  });
}
