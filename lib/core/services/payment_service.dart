import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:endvpn/core/config/app_config.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final _log = Logger();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyPendingPayment = 'pending_payment_id';
  static const _keyPendingDays   = 'pending_payment_days';
  static const _keyPendingUuid   = 'pending_payment_uuid'; // ← device UUID вместо tg_id

  final _dio = Dio(BaseOptions(
    baseUrl: AppConfig.botApiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  /// Создаёт платёж через бот API и открывает ЮКассу
  Future<bool> startPayment({
    required String deviceUuid, // ← device UUID вместо tg_id
    required SubscriptionPlan plan,
  }) async {
    try {
      final resp = await _dio.post('/payment/create', data: {
        'device_uuid': deviceUuid, // ← бот получает UUID устройства
        'plan_id': plan.id,
      });

      final data = resp.data as Map<String, dynamic>;
      if (data['ok'] != true) {
        _log.e('Payment create failed: ${data['error']}');
        return false;
      }

      final paymentId  = data['payment_id'] as String;
      final confirmUrl = data['url'] as String;

      await _storage.write(key: _keyPendingPayment, value: paymentId);
      await _storage.write(key: _keyPendingDays,    value: plan.days.toString());
      await _storage.write(key: _keyPendingUuid,    value: deviceUuid);

      final uri = Uri.parse(confirmUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      _log.e('Payment error: $e');
      return false;
    }
  }

  /// Проверяет статус платежа через бот API
  Future<PaymentStatus> checkPendingPayment() async {
    final paymentId = await _storage.read(key: _keyPendingPayment);
    final daysStr   = await _storage.read(key: _keyPendingDays);
    final uuid      = await _storage.read(key: _keyPendingUuid);

    if (paymentId == null) return PaymentStatus.none;

    try {
      final resp = await _dio.post('/payment/check', data: {
        'payment_id':   paymentId,
        'device_uuid':  uuid ?? '',
      });

      final data   = resp.data as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status == 'succeeded') {
        final days   = int.tryParse(daysStr ?? '30') ?? 30;
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
