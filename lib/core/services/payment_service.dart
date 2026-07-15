import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:endvpn/core/config/app_config.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final _log = Logger();
  final _storage = const FlutterSecureStorage();

  static const _keyPendingPayment = 'pending_payment_id';
  static const _keyPendingDays = 'pending_payment_days';
  static const _keyPendingUuid = 'pending_payment_uuid';

  final _dio = Dio(BaseOptions(
    baseUrl: AppConfig.botApiUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<bool> startPayment({
    required String deviceUuid,
    required SubscriptionPlan plan,
  }) async {
    try {
      final resp = await _postWithRetry('/payment/create', data: {
        'device_uuid': deviceUuid,
        'plan_id': plan.id,
      });

      final data = _asMap(resp.data);
      if (data['ok'] != true) {
        _log.e('Payment create failed: ${data['error'] ?? data}');
        return false;
      }

      final paymentId = data['payment_id']?.toString() ?? '';
      final confirmUrl = data['url']?.toString() ?? '';
      if (paymentId.isEmpty || confirmUrl.isEmpty) {
        _log.e('Payment create returned empty payment id or url');
        return false;
      }

      await _storage.write(key: _keyPendingPayment, value: paymentId);
      await _storage.write(key: _keyPendingDays, value: plan.days.toString());
      await _storage.write(key: _keyPendingUuid, value: deviceUuid);

      final uri = Uri.tryParse(confirmUrl);
      if (uri == null || !uri.hasScheme) {
        _log.e('Payment create returned invalid url: $confirmUrl');
        return false;
      }

      return _launchPaymentUrl(uri);
    } on DioException catch (e) {
      _log.e('Payment network error: ${_dioSummary(e)}');
      return false;
    } catch (e, stackTrace) {
      _log.e('Payment error: $e', stackTrace: stackTrace);
      return false;
    }
  }

  Future<Response<dynamic>> _postWithRetry(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    DioException? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await _dio.post(path, data: data);
      } on DioException catch (e) {
        lastError = e;
        if (!_shouldRetry(e) || attempt == 3) rethrow;
        await Future.delayed(Duration(milliseconds: 450 * attempt));
      }
    }
    throw lastError ?? StateError('Payment request failed');
  }

  bool _shouldRetry(DioException e) {
    final status = e.response?.statusCode ?? 0;
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        status == 429 ||
        status >= 500;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'ok': false, 'error': 'Unexpected response: $data'};
  }

  String _dioSummary(DioException e) {
    final status = e.response?.statusCode;
    final message = e.message ?? e.error?.toString() ?? e.type.name;
    return status == null ? message : '$message (HTTP $status)';
  }

  Future<bool> _launchPaymentUrl(Uri uri) async {
    const modes = kIsWeb
        ? [LaunchMode.platformDefault]
        : [
            LaunchMode.externalApplication,
            LaunchMode.inAppBrowserView,
            LaunchMode.platformDefault,
          ];

    for (final mode in modes) {
      try {
        if (await launchUrl(uri, mode: mode)) return true;
      } catch (e) {
        _log.w('Payment launch failed with $mode: $e');
      }
    }
    return false;
  }

  Future<PaymentStatus> checkPendingPayment() async {
    final paymentId = await _storage.read(key: _keyPendingPayment);
    final daysStr = await _storage.read(key: _keyPendingDays);
    final uuid = await _storage.read(key: _keyPendingUuid);

    if (paymentId == null) return PaymentStatus.none;

    try {
      final resp = await _postWithRetry('/payment/check', data: {
        'payment_id': paymentId,
        'device_uuid': uuid ?? '',
      });

      final data = _asMap(resp.data);
      final status = data['status'] as String?;

      if (status == 'succeeded') {
        final days = int.tryParse(daysStr ?? '30') ?? 30;
        final subUrl = data['sub_url'] as String? ?? '';
        await _clearPending();
        return PaymentStatus(
          success: true,
          days: days,
          paymentId: paymentId,
          subUrl: subUrl,
        );
      } else if (status == 'canceled') {
        await _clearPending();
        return PaymentStatus(success: false, days: 0, paymentId: paymentId);
      }

      return PaymentStatus(
        success: false,
        days: 0,
        paymentId: paymentId,
        isPending: true,
      );
    } catch (e) {
      _log.e('Check payment error: $e');
      return PaymentStatus.none;
    }
  }

  Future<void> _clearPending() async {
    await _storage.delete(key: _keyPendingPayment);
    await _storage.delete(key: _keyPendingDays);
    await _storage.delete(key: _keyPendingUuid);
  }

  Future<bool> hasPendingPayment() async {
    final id = await _storage.read(key: _keyPendingPayment);
    return id != null;
  }
}

class PaymentStatus {
  final bool success;
  final int days;
  final String? paymentId;
  final bool isPending;
  final String subUrl;

  const PaymentStatus({
    required this.success,
    required this.days,
    this.paymentId,
    this.isPending = false,
    this.subUrl = '',
  });

  static const PaymentStatus none = PaymentStatus(success: false, days: 0);
  bool get isNone => paymentId == null;
}
