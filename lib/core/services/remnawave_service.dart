import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endvpn/core/config/app_config.dart';
import 'package:endvpn/core/models/user_model.dart';

class RemnawaveService {
  static final RemnawaveService _instance = RemnawaveService._internal();
  factory RemnawaveService() => _instance;
  RemnawaveService._internal();

  final _log = Logger();

  final _storage = const FlutterSecureStorage();

  Dio? _dio;
  Future<SharedPreferences>? _prefsFuture;

  static const _keyUuid = 'user_uuid';
  static const _keySubUrl = 'user_sub_url';
  static const _keyTgId = 'user_tg_id';
  static const _keyAnonId = 'anon_user_uuid';

  static const _spKeyUuid = 'sp_user_uuid';
  static const _spKeyAnonId = 'sp_anon_uuid';
  static const _spKeySubUrl = 'sp_sub_url';

  static const defaultSquadUuid = '72972871-bb7d-44c7-a9d0-76952720e5f9';
  static const freeSquadUuid = defaultSquadUuid;
  static const freeTrafficLimitBytes = 15 * 1024 * 1024 * 1024;
  static const freeTrafficLimitStrategy = 'MONTH';

  void init() {
    if (_dio != null) return;
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.botApiUrl,
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  Dio get _client {
    if (_dio == null) init();
    return _dio!;
  }

  Future<SharedPreferences> get _prefs =>
      _prefsFuture ??= SharedPreferences.getInstance();

  Future<String?> _readUuidWithFallback(String secureKey, String spKey) async {
    final fromSecure = await _storage.read(key: secureKey);
    if (fromSecure != null && fromSecure.isNotEmpty) return fromSecure;

    final prefs = await _prefs;
    final fromSp = prefs.getString(spKey);
    if (fromSp != null && fromSp.isNotEmpty) {
      _log.i('UUID restored from SharedPreferences backup: $fromSp');
      await _storage.write(key: secureKey, value: fromSp);
      return fromSp;
    }
    return null;
  }

  Future<void> _writeUuidBoth(
      String secureKey, String spKey, String value) async {
    await _storage.write(key: secureKey, value: value);
    final prefs = await _prefs;
    await prefs.setString(spKey, value);
  }

  Future<void> _writeSubUrlBoth(String value) async {
    await _storage.write(key: _keySubUrl, value: value);
    final prefs = await _prefs;
    await prefs.setString(_spKeySubUrl, value);
  }

  Future<String?> _readSubUrlWithFallback() async {
    final fromSecure = await _storage.read(key: _keySubUrl);
    if (fromSecure != null && fromSecure.isNotEmpty) return fromSecure;
    final prefs = await _prefs;
    return prefs.getString(_spKeySubUrl);
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return {};
      }
    }
    if (data is Map<String, dynamic>) {
      if (data.containsKey('response')) {
        final inner = data['response'];
        if (inner is Map<String, dynamic>) return inner;
      }
      if (data.containsKey('user')) {
        final inner = data['user'];
        if (inner is Map<String, dynamic>) return inner;
      }
      return data;
    }
    return {};
  }

  int _parseClicks(String? description) {
    if (description == null) return 0;
    final match = RegExp(r'clicks:(\d+)').firstMatch(description);
    return int.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  String _resolveSubscriptionUrl(Map<String, dynamic> data) {
    final direct = data['subscriptionUrl'] ??
        data['subUrl'] ??
        data['sub_url'] ??
        data['subscription_url'];
    if (direct is String && direct.isNotEmpty) return direct;

    final subscription = data['subscription'];
    if (subscription is Map<String, dynamic>) {
      final nested = subscription['url'] ?? subscription['uri'];
      if (nested is String && nested.isNotEmpty) return nested;
    }

    final shortUuid = data['shortUuid'] ?? data['short_uuid'];
    if (shortUuid is String && shortUuid.isNotEmpty) {
      final base = AppConfig.remnawaveBaseUrl.replaceFirst(RegExp(r'/$'), '');
      return '$base/sub/$shortUuid';
    }

    return '';
  }

  bool _is404(dynamic e) => e is DioException && e.response?.statusCode == 404;

  bool _isNetworkError(dynamic e) =>
      e is DioException &&
      (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout);

  Future<UserModel> getOrCreateAnonUser() async {
    final savedUuid = await _readUuidWithFallback(_keyAnonId, _spKeyAnonId);

    if (savedUuid != null && savedUuid.isNotEmpty) {
      try {
        final user = await _getUserByUuid(savedUuid);

        if (!user.username.startsWith('anon_')) {
          _log.w(
              'Stored anon UUID points to non-anon user (${user.username}) — resetting');
          await _storage.delete(key: _keyAnonId);
          final prefs = await _prefs;
          await prefs.remove(_spKeyAnonId);
          return await _createAnonUser();
        }

        if (user.subscriptionUrl.isNotEmpty) {
          await _writeSubUrlBoth(user.subscriptionUrl);
        }
        _log.i('Loaded anon user: ${user.uuid} (${user.username})');
        return user;
      } catch (e) {
        _log.w('Anon UUID load failed: $e');

        if (_is404(e)) {
          _log.w('Anon user 404 — creating new');
          await _storage.delete(key: _keyAnonId);
          final prefs = await _prefs;
          await prefs.remove(_spKeyAnonId);
          return await _createAnonUser();
        }

        final cachedSub = await _readSubUrlWithFallback() ?? '';
        if (cachedSub.isNotEmpty) {
          return UserModel(
            uuid: savedUuid,
            username: 'anon',
            subscriptionUrl: cachedSub,
            trafficLimitBytes: freeTrafficLimitBytes,
            usedTrafficBytes: 0,
            isActive: true,
            subscriptionType: 'free',
            clickerBalance: 0,
          );
        }

        _log.w('No cache available — creating new anon user');
        return await _createAnonUser();
      }
    }

    return await _createAnonUser();
  }

  Future<UserModel> _createAnonUser() async {
    final resp = await _client.post('/app/anon');
    final user = _mapUser(_unwrap(resp.data));

    await _writeUuidBoth(_keyAnonId, _spKeyAnonId, user.uuid);
    if (user.subscriptionUrl.isNotEmpty) {
      await _writeSubUrlBoth(user.subscriptionUrl);
    }
    _log.i('Created anon user: ${user.uuid} (${user.username})');
    return user;
  }

  Future<UserModel> getOrCreateUserByTgId(int tgId) async {
    final savedUuid = await _readUuidWithFallback(_keyUuid, _spKeyUuid);
    final savedTgId = await _storage.read(key: _keyTgId);

    if (savedUuid != null &&
        savedUuid.isNotEmpty &&
        savedTgId == tgId.toString()) {
      try {
        final user = await _getUserByUuid(savedUuid);
        if (user.subscriptionUrl.isNotEmpty) {
          await _writeSubUrlBoth(user.subscriptionUrl);
        }
        _log.i('Loaded by uuid: ${user.uuid}');
        return user;
      } catch (e) {
        if (_is404(e)) {
          await _storage.delete(key: _keyUuid);
          final prefs = await _prefs;
          await prefs.remove(_spKeyUuid);
        } else if (_isNetworkError(e)) {
          final cachedSub = await _readSubUrlWithFallback() ?? '';
          if (cachedSub.isNotEmpty) {
            return UserModel(
              uuid: savedUuid,
              username: 'tg_$tgId',
              subscriptionUrl: cachedSub,
              trafficLimitBytes: freeTrafficLimitBytes,
              usedTrafficBytes: 0,
              isActive: true,
              subscriptionType: 'free',
              clickerBalance: 0,
            );
          }
        } else {
          _log.w('UUID load failed: $e — clearing cache');
          await _storage.delete(key: _keyUuid);
          final prefs = await _prefs;
          await prefs.remove(_spKeyUuid);
        }
      }
    }

    try {
      final user = await _getUserByTelegramId(tgId);
      await _writeUuidBoth(_keyUuid, _spKeyUuid, user.uuid);
      await _storage.write(key: _keyTgId, value: tgId.toString());
      if (user.subscriptionUrl.isNotEmpty) {
        await _writeSubUrlBoth(user.subscriptionUrl);
      }
      _log.i('Found or created by telegramId: ${user.uuid}');
      return user;
    } catch (e) {
      _log.e('tg user lookup/create failed: $e');
      rethrow;
    }
  }

  Future<UserModel> _getUserByUuid(String uuid) async {
    final resp = await _client.get('/app/user/$uuid');
    final data = _unwrap(resp.data);
    if ((data['uuid'] as String? ?? '').isEmpty) {
      throw Exception('Empty uuid in response');
    }
    return _mapUser(data);
  }

  Future<UserModel> refreshUser(String uuid) async {
    if (uuid.isEmpty) {
      throw ArgumentError.value(uuid, 'uuid', 'User UUID must not be empty');
    }
    final user = await _getUserByUuid(uuid);
    if (user.subscriptionUrl.isNotEmpty) {
      await _writeSubUrlBoth(user.subscriptionUrl);
    }
    return user;
  }

  Future<UserModel> _getUserByTelegramId(int tgId) async {
    final resp = await _client.post('/app/tg', data: {'tg_id': tgId});
    final data = _unwrap(resp.data);
    if ((data['uuid'] as String? ?? '').isEmpty) {
      throw Exception('User with telegramId $tgId not found');
    }
    return _mapUser(data);
  }

  Future<UserModel> applyPromoCode(String uuid, String code) async {
    final resp = await _client.post('/app/promo', data: {
      'uuid': uuid,
      'code': code,
    });
    final user = _mapUser(_unwrap(resp.data));
    if (user.subscriptionUrl.isNotEmpty) {
      await _writeSubUrlBoth(user.subscriptionUrl);
    }
    _log.i('Promo applied: ${user.uuid}');
    return user;
  }

  Future<int> getClickerBalance(String uuid) async {
    final user = await _getUserByUuid(uuid);
    return user.clickerBalance;
  }

  Future<void> saveClickerBalance(String uuid, int clicks) async {
    try {
      await _client.post('/app/clicks', data: {
        'uuid': uuid,
        'clicks': clicks,
      });
    } catch (e) {
      _log.w('saveClickerBalance error: $e');
    }
  }

  UserModel _mapUser(Map<String, dynamic> data) {
    final clicks = _parseClicks(data['description'] as String?);
    final traffic = (data['userTraffic'] as Map<String, dynamic>?) ?? {};
    final trafficLimitBytes = (data['trafficLimitBytes'] as num?)?.toInt() ?? 0;

    return UserModel(
      uuid: data['uuid'] as String? ?? '',
      username: data['username'] as String? ?? '',
      subscriptionUrl: _resolveSubscriptionUrl(data),
      expireAt: data['expireAt'] != null
          ? DateTime.tryParse(data['expireAt'].toString())
          : null,
      trafficLimitBytes: trafficLimitBytes,
      usedTrafficBytes: (traffic['usedTrafficBytes'] as num?)?.toInt() ?? 0,
      isActive: data['status'] == 'ACTIVE',
      subscriptionType: trafficLimitBytes == 0 ? 'paid' : 'free',
      clickerBalance: clicks,
    );
  }

  Future<String?> getSavedUuid() => _readUuidWithFallback(_keyUuid, _spKeyUuid);
  Future<String?> getSavedTgId() => _storage.read(key: _keyTgId);
  Future<String?> getSavedAnonUuid() =>
      _readUuidWithFallback(_keyAnonId, _spKeyAnonId);

  Future<void> saveTgId(int tgId) async {
    await _storage.write(key: _keyTgId, value: tgId.toString());
  }

  Future<void> clearUser() async {
    await _storage.delete(key: _keyUuid);
    await _storage.delete(key: _keyTgId);
    await _storage.delete(key: _keySubUrl);
    final prefs = await _prefs;
    await prefs.remove(_spKeyUuid);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await _prefs;
    await prefs.remove(_spKeyUuid);
    await prefs.remove(_spKeyAnonId);
    await prefs.remove(_spKeySubUrl);
    _log.i('All storage cleared');
  }
}
