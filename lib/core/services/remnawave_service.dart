import 'dart:convert';
import 'dart:math';
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

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Dio? _dio;

  static const _keyUuid   = 'user_uuid';
  static const _keySubUrl = 'user_sub_url';
  static const _keyTgId   = 'user_tg_id';
  static const _keyAnonId = 'anon_user_uuid';

  // SharedPreferences ключи для бэкапа (выживают после переустановки на Android)
  static const _spKeyUuid   = 'sp_user_uuid';
  static const _spKeyAnonId = 'sp_anon_uuid';
  static const _spKeySubUrl = 'sp_sub_url';

  static const freeSquadUuid = '2890e16a-a2be-4049-9413-fb3531a3cbdb';
  static const paidSquadUuid = '833414d4-ca2d-47c0-87da-24d6b38a9f20';

  // ── Lazy init ─────────────────────────────────────────────────────────────

  void init() {
    if (_dio != null) return;
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.remnawaveBaseUrl,
      headers: {
        'Authorization': 'Bearer ${AppConfig.remnawaveToken}',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  Dio get _client {
    if (_dio == null) init();
    return _dio!;
  }

  // ── SharedPreferences бэкап ───────────────────────────────────────────────

  /// Читает UUID: сначала SecureStorage, фолбэк на SharedPreferences
  Future<String?> _readUuidWithFallback(String secureKey, String spKey) async {
    final fromSecure = await _storage.read(key: secureKey);
    if (fromSecure != null && fromSecure.isNotEmpty) return fromSecure;

    // SecureStorage пуст (переустановка?) — пробуем бэкап
    final prefs = await SharedPreferences.getInstance();
    final fromSp = prefs.getString(spKey);
    if (fromSp != null && fromSp.isNotEmpty) {
      _log.i('UUID restored from SharedPreferences backup: $fromSp');
      // Восстанавливаем в SecureStorage
      await _storage.write(key: secureKey, value: fromSp);
      return fromSp;
    }
    return null;
  }

  /// Сохраняет UUID в оба хранилища
  Future<void> _writeUuidBoth(String secureKey, String spKey, String value) async {
    await _storage.write(key: secureKey, value: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(spKey, value);
  }

  /// Сохраняет subUrl в оба хранилища
  Future<void> _writeSubUrlBoth(String value) async {
    await _storage.write(key: _keySubUrl, value: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spKeySubUrl, value);
  }

  Future<String?> _readSubUrlWithFallback() async {
    final fromSecure = await _storage.read(key: _keySubUrl);
    if (fromSecure != null && fromSecure.isNotEmpty) return fromSecure;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_spKeySubUrl);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is String) {
      try { data = jsonDecode(data); } catch (_) { return {}; }
    }
    if (data is Map<String, dynamic>) {
      if (data.containsKey('response')) {
        final inner = data['response'];
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

  String _buildDescription(int clicks) => 'clicks:$clicks';

  bool _is404(dynamic e) =>
      e is DioException && e.response?.statusCode == 404;

  bool _isNetworkError(dynamic e) =>
      e is DioException &&
      (e.type == DioExceptionType.connectionError ||
       e.type == DioExceptionType.connectionTimeout ||
       e.type == DioExceptionType.receiveTimeout ||
       e.type == DioExceptionType.sendTimeout);

  // ─── Анонимный юзер ───────────────────────────────────────────────────────

  Future<UserModel> getOrCreateAnonUser() async {
    final savedUuid = await _readUuidWithFallback(_keyAnonId, _spKeyAnonId);

    if (savedUuid != null && savedUuid.isNotEmpty) {
      try {
        final user = await _getUserByUuid(savedUuid);

        if (!user.username.startsWith('anon_')) {
          _log.w('Stored anon UUID points to non-anon user (${user.username}) — resetting');
          await _storage.delete(key: _keyAnonId);
          final prefs = await SharedPreferences.getInstance();
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
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_spKeyAnonId);
          return await _createAnonUser();
        }

        // Сетевая ошибка — фолбэк на кеш
        final cachedSub = await _readSubUrlWithFallback() ?? '';
        if (cachedSub.isNotEmpty) {
          return UserModel(
            uuid: savedUuid,
            username: 'anon',
            subscriptionUrl: cachedSub,
            trafficLimitBytes: 15 * 1024 * 1024 * 1024,
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
    final rng = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
    final username = 'anon_$suffix';

    final body = {
      'username': username,
      'expireAt': DateTime.now()
          .add(const Duration(days: 36500))
          .toUtc()
          .toIso8601String(),
      'trafficLimitBytes': 15 * 1024 * 1024 * 1024,
      'trafficLimitStrategy': 'NO_RESET',
      'status': 'ACTIVE',
      'hwidDeviceLimit': 2,
      'description': _buildDescription(0),
      'activeInternalSquads': [freeSquadUuid],
    };

    final resp = await _client.post('/api/users', data: body);
    final data = _unwrap(resp.data);
    final user = _mapUser(data);

    await _writeUuidBoth(_keyAnonId, _spKeyAnonId, user.uuid);
    if (user.subscriptionUrl.isNotEmpty) {
      await _writeSubUrlBoth(user.subscriptionUrl);
    }
    _log.i('Created anon user: ${user.uuid} (${user.username})');
    return user;
  }

  // ─── Юзер по Telegram ID ─────────────────────────────────────────────────

  Future<UserModel> getOrCreateUserByTgId(int tgId) async {
    final savedUuid  = await _readUuidWithFallback(_keyUuid, _spKeyUuid);
    final savedTgId  = await _storage.read(key: _keyTgId);

    if (savedUuid != null && savedUuid.isNotEmpty && savedTgId == tgId.toString()) {
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
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_spKeyUuid);
        } else if (_isNetworkError(e)) {
          final cachedSub = await _readSubUrlWithFallback() ?? '';
          if (cachedSub.isNotEmpty) {
            return UserModel(
              uuid: savedUuid,
              username: 'tg_$tgId',
              subscriptionUrl: cachedSub,
              trafficLimitBytes: 10 * 1024 * 1024 * 1024,
              usedTrafficBytes: 0,
              isActive: true,
              subscriptionType: 'free',
              clickerBalance: 0,
            );
          }
        } else {
          _log.w('UUID load failed: $e — clearing cache');
          await _storage.delete(key: _keyUuid);
          final prefs = await SharedPreferences.getInstance();
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
      _log.i('Found by telegramId: ${user.uuid}');
      return user;
    } catch (_) {
      _log.i('Not found by telegramId, creating: tg_$tgId');
    }

    return await _createUser(tgId);
  }

  Future<UserModel> _getUserByUuid(String uuid) async {
    final resp = await _client.get('/api/users/$uuid');
    final data = _unwrap(resp.data);
    if ((data['uuid'] as String? ?? '').isEmpty) {
      throw Exception('Empty uuid in response');
    }
    return _mapUser(data);
  }

  Future<UserModel> _getUserByTelegramId(int tgId) async {
    try {
      final resp = await _client.get('/api/users', queryParameters: {'telegramId': tgId});
      final raw  = _unwrap(resp.data);
      if (raw['users'] is List) {
        final list = raw['users'] as List;
        if (list.isNotEmpty) return _mapUser(list[0] as Map<String, dynamic>);
      }
    } catch (_) {}

    int page = 1;
    const limit = 100;
    while (true) {
      final resp = await _client.get('/api/users',
          queryParameters: {'limit': limit, 'offset': (page - 1) * limit});
      final raw   = _unwrap(resp.data);
      final list  = (raw['users'] as List?) ?? [];
      final total = (raw['total'] as int?) ?? 0;

      for (final item in list) {
        final map = item as Map<String, dynamic>;
        if (map['telegramId'] == tgId) return _mapUser(map);
      }

      if (list.length < limit || page * limit >= total) break;
      page++;
    }

    throw Exception('User with telegramId $tgId not found');
  }

  Future<UserModel> _createUser(int tgId) async {
    final username = 'tg${tgId}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final expireAt = DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String();

    final body = {
      'username': username,
      'telegramId': tgId,
      'trafficLimitBytes': 1 * 1024 * 1024 * 1024,
      'trafficLimitStrategy': 'NO_RESET',
      'expireAt': expireAt,
      'status': 'ACTIVE',
      'hwidDeviceLimit': 2,
      'description': _buildDescription(0),
      'activeInternalSquads': [freeSquadUuid],
    };

    final resp = await _client.post('/api/users', data: body);
    final data = _unwrap(resp.data);
    final user = _mapUser(data);

    await _writeUuidBoth(_keyUuid, _spKeyUuid, user.uuid);
    await _storage.write(key: _keyTgId, value: tgId.toString());
    if (user.subscriptionUrl.isNotEmpty) {
      await _writeSubUrlBoth(user.subscriptionUrl);
    }
    _log.i('Created tg user: ${user.uuid}');
    return user;
  }

  // ─── Активация подписки ───────────────────────────────────────────────────

  Future<UserModel> activateSubscription(String uuid, int days) async {
    int clicks = 0;
    DateTime baseDate = DateTime.now();
    try {
      final current = await _getUserByUuid(uuid);
      clicks = current.clickerBalance;
      if (current.expireAt != null && current.expireAt!.isAfter(DateTime.now())) {
        baseDate = current.expireAt!;
      }
    } catch (_) {}

    final expireAt = baseDate.add(Duration(days: days)).toUtc().toIso8601String();
    final resp = await _client.patch('/api/users/', data: {
      'uuid': uuid,
      'expireAt': expireAt,
      'trafficLimitBytes': 0,
      'status': 'ACTIVE',
      'description': _buildDescription(clicks),
      'activeInternalSquads': [paidSquadUuid],
    });

    final user = _mapUser(_unwrap(resp.data));
    if (user.subscriptionUrl.isNotEmpty) {
      await _writeSubUrlBoth(user.subscriptionUrl);
    }
    _log.i('Activated paid: ${user.uuid}, days: $days');
    return user;
  }

  // ─── Кликер ───────────────────────────────────────────────────────────────

  Future<int> getClickerBalance(String uuid) async {
    final user = await _getUserByUuid(uuid);
    return user.clickerBalance;
  }

  Future<void> saveClickerBalance(String uuid, int clicks) async {
    try {
      await _client.patch('/api/users/', data: {
        'uuid': uuid,
        'description': _buildDescription(clicks),
      });
    } catch (e) {
      _log.w('saveClickerBalance error: $e');
    }
  }

  // ─── User mapping ─────────────────────────────────────────────────────────

  UserModel _mapUser(Map<String, dynamic> data) {
    final squads = (data['activeInternalSquads'] as List?) ?? [];
    final isPaid = squads.any((s) => (s as Map)['uuid'] == paidSquadUuid);
    final clicks = _parseClicks(data['description'] as String?);
    final traffic = (data['userTraffic'] as Map<String, dynamic>?) ?? {};

    return UserModel(
      uuid: data['uuid'] as String? ?? '',
      username: data['username'] as String? ?? '',
      subscriptionUrl: data['subscriptionUrl'] as String? ?? '',
      expireAt: data['expireAt'] != null
          ? DateTime.tryParse(data['expireAt'].toString())
          : null,
      trafficLimitBytes: (data['trafficLimitBytes'] as num?)?.toInt() ?? 0,
      usedTrafficBytes: (traffic['usedTrafficBytes'] as num?)?.toInt() ?? 0,
      isActive: data['status'] == 'ACTIVE',
      subscriptionType: isPaid ? 'paid' : 'free',
      clickerBalance: clicks,
    );
  }

  // ─── Storage helpers ──────────────────────────────────────────────────────

  Future<String?> getSavedUuid()     => _readUuidWithFallback(_keyUuid, _spKeyUuid);
  Future<String?> getSavedTgId()     => _storage.read(key: _keyTgId);
  Future<String?> getSavedAnonUuid() => _readUuidWithFallback(_keyAnonId, _spKeyAnonId);

  Future<void> saveTgId(int tgId) async {
    await _storage.write(key: _keyTgId, value: tgId.toString());
  }

  Future<void> clearUser() async {
    await _storage.delete(key: _keyUuid);
    await _storage.delete(key: _keyTgId);
    await _storage.delete(key: _keySubUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_spKeyUuid);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_spKeyUuid);
    await prefs.remove(_spKeyAnonId);
    await prefs.remove(_spKeySubUrl);
    _log.i('All storage cleared');
  }
}