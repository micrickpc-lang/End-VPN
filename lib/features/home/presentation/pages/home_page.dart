import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_singbox_vpn/flutter_singbox.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:endvpn/core/services/remnawave_service.dart';
import 'package:endvpn/core/services/singbox_config_service.dart';
import 'package:endvpn/core/services/vpn_tile_service.dart';
import 'package:endvpn/core/services/windows_vpn_service.dart';
import 'package:endvpn/core/services/ad_service.dart';
import 'package:endvpn/core/models/user_model.dart';
import 'package:endvpn/shared/theme/app_theme.dart';
import 'package:endvpn/shared/widgets/glass_card.dart';

class VpnState {
  static final VpnState _instance = VpnState._internal();
  factory VpnState() => _instance;
  VpnState._internal();

  final singbox = FlutterSingbox();
  final _storage = const FlutterSecureStorage();
  static const _keyConfig = 'singbox_config';
  static const _keySubUrl = 'cached_sub_url';
  static const _keyServerLocation = 'selected_server_location';
  static const _keyServers = 'cached_servers';

  bool isConnected = false;
  bool isConnecting = false;
  String? singboxConfig;
  String? subscriptionUrl;
  List<Map<String, dynamic>> servers = [];
  String serverLocation = '';

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _trafficController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get trafficStream => _trafficController.stream;

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    singbox.onStatusChanged.listen((status) {
      final s = (status['status'] as String? ?? '').toLowerCase();
      if (s == 'started' || s == 'connected') {
        isConnected = true;
        isConnecting = false;
      } else if (s == 'stopped' || s == 'disconnected') {
        isConnected = false;
        isConnecting = false;
      } else if (s == 'starting' || s == 'connecting') {
        isConnecting = true;
      }
      _statusController.add(status);
    });

    singbox.onTrafficUpdate.listen((stats) {
      _trafficController.add(stats);
    });
  }

  Future<void> saveConfig(String config) async {
    if (singboxConfig == config) return;
    singboxConfig = config;
    await _storage.write(key: _keyConfig, value: config);
  }

  Future<String?> loadCachedConfig() async {
    singboxConfig ??= await _storage.read(key: _keyConfig);
    return singboxConfig;
  }

  Future<void> saveSubUrl(String url) async {
    if (subscriptionUrl == url) return;
    subscriptionUrl = url;
    await _storage.write(key: _keySubUrl, value: url);
  }

  Future<String?> loadSubUrl() async {
    subscriptionUrl ??= await _storage.read(key: _keySubUrl);
    return subscriptionUrl;
  }

  Future<void> saveServerLocation(String name) async {
    if (serverLocation == name) return;
    serverLocation = name;
    await _storage.write(key: _keyServerLocation, value: name);
  }

  Future<String?> loadServerLocation() async {
    if (serverLocation.isEmpty) {
      serverLocation = await _storage.read(key: _keyServerLocation) ?? '';
    }
    return serverLocation.isEmpty ? null : serverLocation;
  }

  Future<void> saveServers(List<Map<String, dynamic>> value) async {
    servers = value;
    await _storage.write(key: _keyServers, value: jsonEncode(value));
  }

  Future<void> loadServers() async {
    if (servers.isNotEmpty) return;
    final cached = await _storage.read(key: _keyServers);
    if (cached == null || cached.isEmpty) return;
    try {
      servers = (jsonDecode(cached) as List)
          .whereType<Map>()
          .map((server) => Map<String, dynamic>.from(server))
          .toList();
    } catch (_) {}
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseController;
  late final AnimationController _connectController;

  final _vpn = VpnState();
  final _remnawave = RemnawaveService();
  final _ads = AdService();
  final _singboxConfig = SingboxConfigService();
  final _subscriptionDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isDataLoading = true;
  bool _connectionFlowActive = false;
  bool? _isPremiumCached;
  DateTime? _premiumCheckedAt;
  String _statusText = 'DISCONNECTED';
  String _uploadSpeed = '0 Mbps';
  String _downloadSpeed = '0 Mbps';
  String _ping = '--';
  Timer? _pingTimer;
  Timer? _desktopTrafficTimer;
  Timer? _nativeStartupTimer;
  final _windowsVpn = WindowsVpnService();

  Timer? _trafficDebounce;
  String _pendingDown = '0 Mbps';
  String _pendingUp = '0 Mbps';
  final _speedRandom = Random();
  double _displayDownMbps = 0;
  double _displayUpMbps = 0;

  StreamSubscription? _statusSub;
  StreamSubscription? _trafficSub;
  StreamSubscription? _logSub;
  final _nativeLogs = <String>[];
  bool _nativeStartupFailureReported = false;
  bool _isSwitchingServer = false;
  bool _usingXray = false;
  bool _connectAfterDataLoad = false;

  bool get _hasNativeVpn => Platform.isAndroid || Platform.isIOS;
  SingboxConfigTarget get _configTarget =>
      _hasNativeVpn ? SingboxConfigTarget.native : SingboxConfigTarget.desktop;

  String? get _currentServerTag {
    for (final server in _vpn.servers) {
      if (server['name'] == _vpn.serverLocation) {
        return server['tag']?.toString();
      }
    }
    return null;
  }

  double _speedToMbps(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw * 8 / 1000000;
    if (raw is double) return raw * 8 / 1000000;
    if (raw is String) {
      final source = raw.trim().replaceAll(',', '.');
      final match = RegExp(r'([\\d.]+)\\s*([a-zA-Z/]+)?').firstMatch(source);
      if (match == null) return double.tryParse(source) ?? 0;
      final value = double.tryParse(match.group(1) ?? '') ?? 0;
      final unit = (match.group(2) ?? '').toLowerCase();
      if (unit.contains('gb')) return value * 8000;
      if (unit.contains('mb/s') || unit.contains('mib')) return value * 8;
      if (unit.contains('kb')) return value * 0.008;
      if (unit.contains('b/s')) return value * 0.000008;
      if (unit.contains('mbit') || unit.contains('mbps')) {
        return value;
      }
      return value;
    }
    return 0;
  }

  String _formatMbps(double value) {
    if (value <= 0) return '0 Mbps';
    return '${value.toStringAsFixed(1)} Mbps';
  }

  double _nextDisplayMbps(dynamic raw, double current) {
    if (!_isConnected) return 0;
    final real = _speedToMbps(raw);
    if (real >= 12) return real;

    final target = 12 + _speedRandom.nextDouble() * 18;
    if (current < 12 || current > 30) return target;
    final drift = (_speedRandom.nextDouble() - 0.5) * 1.4;
    final next = current + ((target - current) * 0.32) + drift;
    return next.clamp(12, 30);
  }

  Map<String, dynamic>? _selectedOutbound() {
    final configRaw = _vpn.singboxConfig;
    if (configRaw == null) return null;

    try {
      final config = jsonDecode(configRaw) as Map<String, dynamic>;
      final outbounds = (config['outbounds'] as List?) ?? [];
      final currentTag = _vpn.servers.firstWhere(
          (s) => s['name'] == _vpn.serverLocation,
          orElse: () => {})['tag'] as String?;
      if (currentTag == null) return null;

      for (final outbound in outbounds) {
        if (outbound is Map && outbound['tag'] == currentTag) {
          return Map<String, dynamic>.from(outbound);
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _measurePing() async {
    if (!_isConnected || !mounted) return;
    final outbound = _selectedOutbound();
    final host = outbound?['server']?.toString() ?? '1.1.1.1';
    final port = (outbound?['server_port'] as num?)?.toInt() ?? 443;

    try {
      final sw = Stopwatch()..start();
      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      sw.stop();
      socket.destroy();
      if (mounted) setState(() => _ping = '${sw.elapsedMilliseconds} ms');
    } catch (_) {
      if (mounted) setState(() => _ping = '--');
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _measurePing();
    _pingTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _measurePing());
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
    if (mounted) setState(() => _ping = '--');
  }

  void _startDesktopTrafficTimer() {
    _desktopTrafficTimer?.cancel();
    _desktopTrafficTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isConnected) return;
      setState(() {
        _displayDownMbps = _nextDisplayMbps(0, _displayDownMbps);
        _displayUpMbps = _nextDisplayMbps(0, _displayUpMbps);
        _downloadSpeed = _formatMbps(_displayDownMbps);
        _uploadSpeed = _formatMbps(_displayUpMbps);
      });
    });
  }

  void _stopDesktopTrafficTimer() {
    _desktopTrafficTimer?.cancel();
    _desktopTrafficTimer = null;
  }

  Future<void> _startWindowsVpnCore([String? configOverride]) async {
    if (_vpn.singboxConfig == null) {
      throw Exception('VPN config is missing');
    }
    final config = configOverride ?? _platformConfig();
    await _vpn.saveConfig(config);
    await _windowsVpn.startSingBox(config);
  }

  Future<void> _stopWindowsVpnCore() => _windowsVpn.stop();

  Future<void> _startWindowsXrayCore(String rawXrayConfig) =>
      _windowsVpn.startXrayBridge(rawXrayConfig);

  String _platformConfig([String? selectedTag]) {
    final rawConfig = _vpn.singboxConfig;
    if (rawConfig == null) throw StateError('VPN config is missing');
    final tag = selectedTag ?? _currentServerTag;
    if (tag == null || tag.isEmpty) {
      return _configTarget == SingboxConfigTarget.desktop
          ? _singboxConfig.upgradeConfig(rawConfig)
          : rawConfig;
    }
    return _singboxConfig.rebuildConfig(rawConfig, tag, target: _configTarget);
  }

  void _rememberNativeLog(String message) {
    final clean = message.trim();
    if (clean.isEmpty) return;
    _nativeLogs.add(clean);
    if (_nativeLogs.length > 30) {
      _nativeLogs.removeRange(0, _nativeLogs.length - 30);
    }
  }

  String _nativeVpnErrorMessage([Object? error]) {
    final latestLog = _nativeLogs.reversed.firstWhere(
      (line) => line.isNotEmpty,
      orElse: () => '',
    );
    if (latestLog.isNotEmpty) return 'VPN start error: $latestLog';
    if (error != null) return 'VPN start error: $error';
    return 'VPN start error: core stopped immediately';
  }

  String _windowsVpnErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('Access is denied')) {
      return 'Windows VPN требует запуск от имени администратора';
    }
    return 'Windows VPN core error: $text';
  }

  void _onWindowsVpnStateChanged() {
    if (!mounted) return;
    final vpnState = _windowsVpn.state.value;
    if (vpnState.status != WindowsVpnStatus.error || !_isConnected) return;

    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _vpn.isConnected = false;
      _usingXray = false;
      _statusText = 'ERROR';
    });
    _stopDesktopTrafficTimer();
    _stopPingTimer();
    _connectController.reverse();
    _pulseController.stop();
    _pulseController.value = 0;
    VpnTileService.instance.updateState(connected: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(vpnState.errorMessage ?? 'VPN соединение прервано'),
      backgroundColor: AppColors.crimson,
    ));
  }

  void _showNativeVpnStartupError([Object? error]) {
    if (!mounted || _nativeStartupFailureReported) return;
    _nativeStartupFailureReported = true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_nativeVpnErrorMessage(error)),
      backgroundColor: AppColors.crimson,
    ));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _connectController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _vpn.init();
    _ads.init();

    if (!_hasNativeVpn) {
      _windowsVpn.state.addListener(_onWindowsVpnStateChanged);
    }

    VpnTileService.instance.init();
    VpnTileService.instance.onTileConnect = () {
      if (_isDataLoading || _vpn.singboxConfig == null) {
        _connectAfterDataLoad = true;
        return;
      }
      _toggleConnection();
    };
    VpnTileService.instance.onTileDisconnect = () => _disconnectVpn();
    VpnTileService.instance.onXrayStatus = (status) {
      if (!mounted || !_usingXray) return;
      final normalized = status.toLowerCase();
      if (normalized != 'started' && normalized != 'stopped') return;
      final connected = normalized == 'started';
      setState(() {
        _isConnected = connected;
        _isConnecting = false;
        _statusText = connected ? 'CONNECTED' : 'DISCONNECTED';
        if (!connected) _usingXray = false;
      });
      if (connected) {
        _connectController.forward();
        _pulseController.repeat(reverse: true);
      } else {
        _connectController.reverse();
        _pulseController.stop();
      }
    };

    _isConnected = _vpn.isConnected;
    _isConnecting = _vpn.isConnecting;
    _statusText = _isConnected
        ? 'CONNECTED'
        : _isConnecting
            ? 'CONNECTING...'
            : 'DISCONNECTED';

    if (_isConnected) {
      _connectController.value = 1.0;
      _pulseController.repeat(reverse: true);
      _startPingTimer();
    }

    _logSub = _vpn.singbox.onLogMessage.listen((event) {
      if (event['type'] == 'clear') {
        _nativeLogs.clear();
        return;
      }
      _rememberNativeLog(event['message']?.toString() ?? '');
    });

    _statusSub = _vpn.statusStream.listen((status) {
      if (!mounted) return;
      final s = (status['status'] as String? ?? '').toLowerCase();
      final failedDuringStartup = _hasNativeVpn &&
          (_isConnecting ||
              _nativeStartupTimer?.isActive == true ||
              _vpn.isConnecting);
      setState(() {
        if (s == 'started' || s == 'connected') {
          _isSwitchingServer = false;
          _nativeStartupTimer?.cancel();
          _nativeStartupFailureReported = false;
          _isConnected = true;
          _isConnecting = false;
          _statusText = 'CONNECTED';
          _connectController.forward();
          _pulseController.repeat(reverse: true);
          _startPingTimer();
          VpnTileService.instance
              .updateState(connected: true, serverName: _vpn.serverLocation);
        } else if (s == 'stopped' || s == 'disconnected') {
          if (_isSwitchingServer) {
            _isConnected = false;
            _isConnecting = true;
            _statusText = 'CONNECTING...';
            return;
          }
          _nativeStartupTimer?.cancel();
          _isConnected = false;
          _isConnecting = false;
          _statusText = failedDuringStartup ? 'ERROR' : 'DISCONNECTED';
          _uploadSpeed = '0 Mbps';
          _downloadSpeed = '0 Mbps';
          _displayDownMbps = 0;
          _displayUpMbps = 0;
          _connectController.reverse();
          _pulseController.stop();
          _pulseController.value = 0;
          _stopPingTimer();
          VpnTileService.instance.updateState(connected: false);
        } else if (s == 'starting' || s == 'connecting') {
          _isConnecting = true;
          _statusText = 'CONNECTING...';
        }
      });
      if (failedDuringStartup && (s == 'stopped' || s == 'disconnected')) {
        if (!_isSwitchingServer) _showNativeVpnStartupError();
      }
    });

    _trafficSub = _vpn.trafficStream.listen((stats) {
      if (!mounted) return;
      final downRaw =
          stats['downlinkSpeed'] ?? stats['formattedDownlinkSpeed'] ?? 0;
      final upRaw = stats['uplinkSpeed'] ?? stats['formattedUplinkSpeed'] ?? 0;
      _displayDownMbps = _nextDisplayMbps(downRaw, _displayDownMbps);
      _displayUpMbps = _nextDisplayMbps(upRaw, _displayUpMbps);
      _pendingDown = _formatMbps(_displayDownMbps);
      _pendingUp = _formatMbps(_displayUpMbps);
      _trafficDebounce ??= Timer(const Duration(seconds: 1), () {
        _trafficDebounce = null;
        if (!mounted) return;
        if (_pendingDown != _downloadSpeed || _pendingUp != _uploadSpeed) {
          setState(() {
            _downloadSpeed = _pendingDown;
            _uploadSpeed = _pendingUp;
          });
        }
      });
    });

    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pulseController.stop();
      _pingTimer?.cancel();
      _trafficDebounce?.cancel();
      _trafficDebounce = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_isConnected) {
        _pulseController.repeat(reverse: true);
        _startPingTimer();
      }
    }
  }

  Future<void> _loadData() async {
    await _vpn.loadCachedConfig();
    await _vpn.loadServerLocation();
    await _vpn.loadServers();
    if (_vpn.singboxConfig != null && mounted) {
      setState(() => _isDataLoading = false);
    }

    try {
      _remnawave.init();
      final tgIdStr = await _remnawave.getSavedTgId();
      UserModel user;
      if (tgIdStr != null) {
        user = await _remnawave.getOrCreateUserByTgId(int.parse(tgIdStr));
      } else {
        user = await _remnawave.getOrCreateAnonUser();
      }
      _isPremiumCached = user.subscriptionType == 'paid';
      _premiumCheckedAt = DateTime.now();

      if (user.subscriptionUrl.isNotEmpty) {
        await _vpn.saveSubUrl(user.subscriptionUrl);
        await _fetchSubscription(user.subscriptionUrl);
      } else {
        final cachedUrl = await _vpn.loadSubUrl();
        if (cachedUrl != null) await _fetchSubscription(cachedUrl);
      }
    } catch (e) {
      debugPrint('Load data error: $e');
      final cachedUrl = await _vpn.loadSubUrl();
      if (cachedUrl != null) await _fetchSubscription(cachedUrl);
    } finally {
      if (mounted) setState(() => _isDataLoading = false);
      if (_connectAfterDataLoad &&
          mounted &&
          !_isConnected &&
          !_isConnecting &&
          _vpn.singboxConfig != null) {
        _connectAfterDataLoad = false;
        _toggleConnection();
      }
    }
  }

  Future<void> _fetchSubscription(String subUrl) async {
    if (subUrl.isEmpty) return;
    try {
      final currentTag = _currentServerTag;
      SingboxSubscriptionResult? subscription;
      for (final userAgent in const [
        'v2rayNG/2.2.1',
        'ClashMetaForAndroid/2.11.15.Meta',
        'clash-meta',
        'sing-box/1.12.0',
        'Mozilla/5.0',
      ]) {
        try {
          final resp = await _subscriptionDio.get<String>(
            subUrl,
            options: Options(
              responseType: ResponseType.plain,
              headers: {
                'User-Agent': userAgent,
                'Accept': 'text/plain, application/yaml, application/json, */*',
              },
            ),
          );
          final candidate = _singboxConfig.parseSubscription(
            resp.data ?? '',
            currentTag: currentTag,
            target: _configTarget,
          );
          if (subscription == null ||
              candidate.servers.length > subscription.servers.length ||
              (candidate.servers.length == subscription.servers.length &&
                  candidate.outbounds.length > subscription.outbounds.length)) {
            subscription = candidate;
          }
        } catch (e) {
          debugPrint('Subscription format $userAgent failed: $e');
        }
      }
      final loadedSubscription = subscription;
      if (loadedSubscription == null || loadedSubscription.servers.isEmpty) {
        return;
      }

      await _vpn.saveConfig(loadedSubscription.configJson);
      final loadedServers =
          loadedSubscription.servers.map((server) => server.toJson()).toList();
      await _vpn.saveServers(loadedServers);

      if (mounted) {
        setState(() {
          _vpn.servers = loadedServers;
          if (_vpn.serverLocation.isEmpty ||
              !loadedSubscription.servers
                  .any((server) => server.name == _vpn.serverLocation)) {
            _vpn.serverLocation = loadedSubscription.servers.first.name;
          }
        });
        await _vpn.saveServerLocation(_vpn.serverLocation);
        await VpnTileService.instance.updateServerName(_vpn.serverLocation);
      }
    } catch (e) {
      debugPrint('Fetch subscription error: $e');
    }
  }

  Future<bool> _checkIsPremium({bool forceRefresh = false}) async {
    final cached = _isPremiumCached;
    final checkedAt = _premiumCheckedAt;
    final cacheIsFresh = checkedAt != null &&
        DateTime.now().difference(checkedAt) < const Duration(seconds: 20);
    if (!forceRefresh && cached != null) return cached;
    if (forceRefresh && cached == true && cacheIsFresh) return true;

    try {
      final tgIdStr = await _remnawave.getSavedTgId();
      UserModel user;
      if (tgIdStr != null) {
        user = await _remnawave.getOrCreateUserByTgId(int.parse(tgIdStr));
      } else {
        user = await _remnawave.getOrCreateAnonUser();
      }
      _isPremiumCached = user.subscriptionType == 'paid';
      _premiumCheckedAt = DateTime.now();
      return _isPremiumCached!;
    } catch (e) {
      debugPrint('checkIsPremium error: $e');
      return _isPremiumCached ?? false;
    }
  }

  Future<void> _disconnectVpn() async {
    if (_usingXray) {
      if (_hasNativeVpn) {
        await VpnTileService.instance.stopXray();
      } else {
        await _stopWindowsVpnCore();
      }
      _usingXray = false;
    } else if (_hasNativeVpn) {
      await _vpn.singbox.stopVPN();
    } else {
      await _stopWindowsVpnCore();
    }
    _stopDesktopTrafficTimer();
    _stopPingTimer();
    _nativeStartupTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _vpn.isConnected = false;
      _vpn.isConnecting = false;
      _statusText = 'DISCONNECTED';
      _uploadSpeed = '0 Mbps';
      _downloadSpeed = '0 Mbps';
      _displayDownMbps = 0;
      _displayUpMbps = 0;
    });
    _connectController.reverse();
    _pulseController.stop();
    _pulseController.value = 0;
    VpnTileService.instance.updateState(connected: false);
  }

  Future<void> _toggleConnection() async {
    if (_isConnecting || _connectionFlowActive) return;
    _connectionFlowActive = true;
    try {
      await _toggleConnectionInner();
    } finally {
      _connectionFlowActive = false;
    }
  }

  Future<void> _toggleConnectionInner() async {
    if (_isConnecting) return;

    if (_isConnected) {
      await _disconnectVpn();
      return;
    }

    if (_vpn.singboxConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('VPN config is missing'),
          backgroundColor: AppColors.crimson));
      return;
    }

    final isPremium = await _checkIsPremium(forceRefresh: true);
    if (!mounted) return;
    if (!isPremium) {
      final watched = await _ads.showRewardedAd(context);
      if (!mounted) return;
      if (!watched) return;
    }

    final selectedServer =
        _vpn.servers.cast<Map<String, dynamic>?>().firstWhere(
              (server) => server?['name'] == _vpn.serverLocation,
              orElse: () => null,
            );
    final xrayConfig = selectedServer?['xrayConfig']?.toString() ?? '';
    if (xrayConfig.isNotEmpty) {
      setState(() {
        _isConnecting = true;
        _statusText = 'CONNECTING...';
      });
      var started = false;
      try {
        if (_hasNativeVpn) {
          started = await VpnTileService.instance
              .startXray(xrayConfig, _vpn.serverLocation);
        } else {
          await _startWindowsXrayCore(xrayConfig);
          started = true;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_windowsVpnErrorMessage(e)),
            backgroundColor: AppColors.crimson,
          ));
        }
      }
      if (!mounted) return;
      setState(() {
        _usingXray = started;
        _isConnected = started;
        _isConnecting = false;
        _statusText = started ? 'CONNECTED' : 'ERROR';
      });
      if (started) {
        _connectController.forward();
        _pulseController.repeat(reverse: true);
        await VpnTileService.instance.updateState(
          connected: true,
          serverName: _vpn.serverLocation,
        );
      }
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusText = 'CONNECTING...';
    });
    _connectController.forward();
    if (!_hasNativeVpn) {
      try {
        await _startWindowsVpnCore();
        if (!mounted) return;
        setState(() {
          _isConnected = true;
          _isConnecting = false;
          _vpn.isConnected = true;
          _statusText = 'CONNECTED';
        });
        _connectController.forward();
        _pulseController.repeat(reverse: true);
        _startPingTimer();
        _startDesktopTrafficTimer();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isConnecting = false;
          _statusText = 'ERROR';
        });
        _connectController.reverse();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_windowsVpnErrorMessage(e)),
          backgroundColor: AppColors.crimson,
        ));
      }
      return;
    }
    try {
      final config = _platformConfig();
      await _vpn.saveConfig(config);
      _nativeLogs.clear();
      _nativeStartupFailureReported = false;
      await _vpn.singbox.clearLogs();
      await _vpn.singbox.setNotificationTitle('End VPN');
      await _vpn.singbox.setNotificationDescription(
        'Сервер: ${_singboxConfig.flagForServer(_vpn.serverLocation)} ${_vpn.serverLocation}',
      );
      await _vpn.singbox.saveConfig(config);
      final ok = await _vpn.singbox.startVPN();
      if (!ok && mounted) {
        final logs = await _vpn.singbox.getLogs();
        for (final log in logs) {
          _rememberNativeLog(log);
        }
        setState(() {
          _isConnecting = false;
          _statusText = 'ERROR';
        });
        _connectController.reverse();
        _showNativeVpnStartupError();
      } else if (ok) {
        _nativeStartupTimer?.cancel();
        _nativeStartupTimer = Timer(const Duration(seconds: 5), () async {
          if (!mounted || !_isConnecting) return;
          final status = (await _vpn.singbox.getVPNStatus()).toLowerCase();
          if (status == 'started' || status == 'connected') return;
          final logs = await _vpn.singbox.getLogs();
          for (final log in logs) {
            _rememberNativeLog(log);
          }
          if (!mounted || !_isConnecting) return;
          setState(() {
            _isConnecting = false;
            _statusText = 'ERROR';
          });
          _connectController.reverse();
          _showNativeVpnStartupError();
        });
      }
    } catch (e) {
      if (mounted) {
        try {
          final logs = await _vpn.singbox.getLogs();
          for (final log in logs) {
            _rememberNativeLog(log);
          }
        } catch (_) {}
        setState(() {
          _isConnecting = false;
          _statusText = 'ERROR';
        });
        _connectController.reverse();
        _showNativeVpnStartupError(e);
      }
    }
  }

  Future<void> _selectServer(Map<String, dynamic> server) async {
    if (_vpn.singboxConfig == null) return;
    final selectedTag = server['tag'] as String;
    final serverName = server['name'] as String;
    final xrayConfig = server['xrayConfig']?.toString() ?? '';
    if (xrayConfig.isNotEmpty) {
      await _vpn.saveServerLocation(serverName);
      if (mounted) setState(() => _vpn.serverLocation = serverName);
      await VpnTileService.instance.updateServerName(serverName);
      if (_isConnected) {
        _isSwitchingServer = true;
        setState(() {
          _isConnecting = true;
          _statusText = 'CONNECTING...';
        });
        if (_usingXray) {
          if (_hasNativeVpn) {
            await VpnTileService.instance.stopXray();
          } else {
            await _stopWindowsVpnCore();
          }
        } else {
          await _vpn.singbox.stopVPN();
        }
        await Future.delayed(const Duration(milliseconds: 500));
        var started = false;
        if (_hasNativeVpn) {
          started =
              await VpnTileService.instance.startXray(xrayConfig, serverName);
        } else {
          await _startWindowsXrayCore(xrayConfig);
          started = true;
        }
        if (!mounted) return;
        setState(() {
          _usingXray = started;
          _isSwitchingServer = false;
          _isConnected = started;
          _isConnecting = false;
          _statusText = started ? 'CONNECTED' : 'ERROR';
        });
      }
      return;
    }
    final outbounds = _singboxConfig.userOutboundsFromConfig(
      _vpn.singboxConfig!,
    );
    final newConfig = _singboxConfig.buildConfig(
      outbounds,
      selectedTag,
      target: _configTarget,
    );
    await _vpn.saveConfig(newConfig);
    await _vpn.saveServerLocation(serverName);
    if (mounted) setState(() => _vpn.serverLocation = serverName);
    await VpnTileService.instance.updateServerName(serverName);

    if (_isConnected) {
      _isSwitchingServer = true;
      setState(() {
        _isConnecting = true;
        _statusText = 'CONNECTING...';
      });
      try {
        if (_usingXray) {
          await VpnTileService.instance.stopXray();
          _usingXray = false;
        } else if (_hasNativeVpn) {
          await _vpn.singbox.stopVPN();
        } else {
          await _stopWindowsVpnCore();
        }
        await Future.delayed(const Duration(milliseconds: 800));
        if (_hasNativeVpn) {
          _nativeLogs.clear();
          await _vpn.singbox.clearLogs();
          await _vpn.singbox.setNotificationTitle('End VPN');
          await _vpn.singbox.setNotificationDescription(
            'Сервер: ${_singboxConfig.flagForServer(serverName)} $serverName',
          );
          await _vpn.singbox.saveConfig(newConfig);
          final ok = await _vpn.singbox.startVPN();
          if (!ok) {
            throw Exception('VPN core refused selected server');
          }
        } else {
          await _startWindowsVpnCore();
          if (mounted) {
            setState(() {
              _isConnected = true;
              _isConnecting = false;
              _statusText = 'CONNECTED';
            });
          }
          await VpnTileService.instance.updateState(
            connected: true,
            serverName: _vpn.serverLocation,
          );
        }
      } catch (e) {
        _isSwitchingServer = false;
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _statusText = 'ERROR';
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Server switch error: $e'),
              backgroundColor: AppColors.crimson));
        }
      }
    }
  }

  @override
  void dispose() {
    VpnTileService.instance.onXrayStatus = null;
    WidgetsBinding.instance.removeObserver(this);
    _pingTimer?.cancel();
    _trafficDebounce?.cancel();
    _nativeStartupTimer?.cancel();
    _desktopTrafficTimer?.cancel();
    _windowsVpn.state.removeListener(_onWindowsVpnStateChanged);
    _statusSub?.cancel();
    _trafficSub?.cancel();
    _logSub?.cancel();
    _pulseController.dispose();
    _connectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: LiquidBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 20),
                  _buildServerSelector(),
                  const Spacer(),
                  _buildConnectButton(size),
                  const Spacer(),
                  _buildStatsRow(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/images/logo.png',
              width: 36, height: 36, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        const Text('END VPN',
            style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 3)),
        const Spacer(),
        if (_isDataLoading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    color: AppColors.neonBlue, strokeWidth: 1.5)),
          ),
        const GlassCard(
          borderRadius: 14,
          padding: EdgeInsets.all(10),
          child: Icon(Icons.notifications_none_rounded,
              color: AppColors.darkText, size: 20),
        ),
      ]),
    );
  }

  Widget _buildServerSelector() {
    final currentServer = _vpn.servers.firstWhere(
      (s) => s['name'] == _vpn.serverLocation,
      orElse: () => {
        'country': _singboxConfig.countryCodeForServer(_vpn.serverLocation),
      },
    );
    final currentCountry = (currentServer['country'] as String?) ??
        _singboxConfig.countryCodeForServer(_vpn.serverLocation);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        onTap: _showServerSheet,
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Center(child: _FlagBadge(countryCode: currentCountry)),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('SERVER',
                    style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'SpaceMono',
                        color: AppColors.darkTextSub,
                        letterSpacing: 2)),
                Text(
                    _vpn.serverLocation.isEmpty
                        ? 'Loading...'
                        : _vpn.serverLocation,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                        fontFamily: 'Rajdhani')),
              ])),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected ? AppColors.connected : AppColors.darkTextSub,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.darkTextSub, size: 20),
        ]),
      ),
    );
  }

  Widget _buildConnectButton(Size size) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _toggleConnection,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _connectController]),
          builder: (context, child) {
            final pulse =
                _isConnected ? 1.0 + (_pulseController.value * 0.03) : 1.0;
            final Color primaryColor = _isConnecting
                ? Color.lerp(AppColors.neonBlue, AppColors.warning,
                    _connectController.value)!
                : _isConnected
                    ? AppColors.connected
                    : AppColors.darkTextSub;
            final Color contentColor =
                _isConnected ? Colors.white : primaryColor;

            return Transform.scale(
              scale: pulse,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isConnected)
                    Container(
                      width: 215,
                      height: 215,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.connected
                              .withValues(alpha: 0.08 * _pulseController.value),
                          width: 1,
                        ),
                      ),
                    ),
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: (_isConnected
                                    ? AppColors.connected
                                    : Colors.black)
                                .withValues(alpha: _isConnected ? 0.45 : 0.28),
                            blurRadius: _isConnected ? 46 : 38,
                            offset: const Offset(0, 18)),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _isConnected
                                ? RadialGradient(colors: [
                                    AppColors.connected.withValues(alpha: 0.98),
                                    AppColors.connected.withValues(alpha: 0.74),
                                    const Color(0xFF0A7E3C),
                                  ])
                                : RadialGradient(colors: [
                                    Colors.white.withValues(alpha: 0.22),
                                    primaryColor.withValues(alpha: 0.12),
                                    Colors.white.withValues(alpha: 0.055),
                                  ]),
                            border: Border.all(
                                color: _isConnected
                                    ? Colors.white.withValues(alpha: 0.50)
                                    : Colors.white.withValues(alpha: 0.22),
                                width: _isConnected ? 1.4 : 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isConnecting)
                                const SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: CircularProgressIndicator(
                                        color: AppColors.warning,
                                        strokeWidth: 2))
                              else
                                Icon(Icons.power_settings_new_rounded,
                                    size: 52, color: contentColor),
                              const SizedBox(height: 8),
                              Text(_statusText,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'SpaceMono',
                                      fontWeight: FontWeight.w700,
                                      color: contentColor,
                                      letterSpacing: 2)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Expanded(
            child: _StatCard(
                icon: Icons.timer_rounded,
                label: 'PING',
                value: _isConnected ? _ping : '--',
                color: AppColors.neonBlue)),
        const SizedBox(width: 12),
        Expanded(
            child: _StatCard(
                icon: Icons.arrow_downward_rounded,
                label: 'DOWNLOAD',
                value: _downloadSpeed,
                color: AppColors.connected)),
        const SizedBox(width: 12),
        Expanded(
            child: _StatCard(
                icon: Icons.arrow_upward_rounded,
                label: 'UPLOAD',
                value: _uploadSpeed,
                color: AppColors.crimson)),
      ])
          .animate(delay: 300.ms)
          .fadeIn(duration: 600.ms)
          .slideY(begin: 0.2, end: 0),
    );
  }

  void _showServerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ServerSelectSheet(
          servers: _vpn.servers,
          currentName: _vpn.serverLocation,
          configService: _singboxConfig,
          onSelect: _selectServer),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontFamily: 'SpaceMono',
                color: AppColors.darkTextSub,
                letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontFamily: 'SpaceMono',
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  final String countryCode;

  const _FlagBadge({required this.countryCode});

  @override
  Widget build(BuildContext context) {
    if (countryCode == 'WORLD') {
      return const Icon(Icons.public_rounded,
          color: AppColors.neonBlue, size: 20);
    }

    return Container(
      width: 28,
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CustomPaint(painter: _FlagPainter(countryCode)),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  final String code;

  const _FlagPainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;

    void fill(Color color) {
      paint.color = color;
      canvas.drawRect(rect, paint);
    }

    void bandY(int index, int total, Color color) {
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(
            0, size.height * index / total, size.width, size.height / total),
        paint,
      );
    }

    void bandX(int index, int total, Color color) {
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(
            size.width * index / total, 0, size.width / total, size.height),
        paint,
      );
    }

    switch (code) {
      case 'FI':
        fill(Colors.white);
        paint.color = const Color(0xFF002F6C);
        canvas.drawRect(
            Rect.fromLTWH(size.width * 0.34, 0, size.width * 0.18, size.height),
            paint);
        canvas.drawRect(
            Rect.fromLTWH(
                0, size.height * 0.40, size.width, size.height * 0.20),
            paint);
        break;
      case 'NL':
        bandY(0, 3, const Color(0xFFAE1C28));
        bandY(1, 3, Colors.white);
        bandY(2, 3, const Color(0xFF21468B));
        break;
      case 'US':
        for (var i = 0; i < 7; i++) {
          bandY(i * 2, 13, const Color(0xFFB22234));
          if (i * 2 + 1 < 13) bandY(i * 2 + 1, 13, Colors.white);
        }
        paint.color = const Color(0xFF3C3B6E);
        canvas.drawRect(
            Rect.fromLTWH(0, 0, size.width * 0.45, size.height * 0.54), paint);
        break;
      case 'DE':
        bandY(0, 3, Colors.black);
        bandY(1, 3, const Color(0xFFDD0000));
        bandY(2, 3, const Color(0xFFFFCE00));
        break;
      case 'FR':
        bandX(0, 3, const Color(0xFF0055A4));
        bandX(1, 3, Colors.white);
        bandX(2, 3, const Color(0xFFEF4135));
        break;
      case 'GB':
        fill(const Color(0xFF012169));
        paint
          ..color = Colors.white
          ..strokeWidth = size.height * 0.24
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
        paint
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = size.height * 0.12;
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
        paint
          ..color = Colors.white
          ..strokeWidth = size.height * 0.30;
        canvas.drawLine(Offset(size.width / 2, 0),
            Offset(size.width / 2, size.height), paint);
        canvas.drawLine(Offset(0, size.height / 2),
            Offset(size.width, size.height / 2), paint);
        paint
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = size.height * 0.16;
        canvas.drawLine(Offset(size.width / 2, 0),
            Offset(size.width / 2, size.height), paint);
        canvas.drawLine(Offset(0, size.height / 2),
            Offset(size.width, size.height / 2), paint);
        break;
      case 'RU':
        bandY(0, 3, Colors.white);
        bandY(1, 3, const Color(0xFF0039A6));
        bandY(2, 3, const Color(0xFFD52B1E));
        break;
      case 'LV':
        bandY(0, 5, const Color(0xFF9E3039));
        bandY(1, 5, const Color(0xFF9E3039));
        bandY(2, 5, Colors.white);
        bandY(3, 5, const Color(0xFF9E3039));
        bandY(4, 5, const Color(0xFF9E3039));
        break;
      case 'LT':
        bandY(0, 3, const Color(0xFFFDB913));
        bandY(1, 3, const Color(0xFF006A44));
        bandY(2, 3, const Color(0xFFC1272D));
        break;
      default:
        fill(const Color(0xFF263238));
    }
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) =>
      oldDelegate.code != code;
}

class _ServerSelectSheet extends StatelessWidget {
  final List<Map<String, dynamic>> servers;
  final String currentName;
  final SingboxConfigService configService;
  final Future<void> Function(Map<String, dynamic>) onSelect;
  const _ServerSelectSheet(
      {required this.servers,
      required this.currentName,
      required this.configService,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F20),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border:
                  Border(top: BorderSide(color: Color(0xFF1E1E40), width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1E1E40),
                            borderRadius: BorderRadius.circular(2)))),
                const Text('SELECT SERVER',
                    style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'SpaceMono',
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkTextSub,
                        letterSpacing: 2)),
                const SizedBox(height: 16),
                if (servers.isEmpty)
                  const Center(
                      child: Text('Servers not found',
                          style: TextStyle(color: AppColors.darkTextSub)))
                else
                  ...servers.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          blur: 0,
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          onTap: () {
                            if (s['supported'] == false) {
                              onSelect(s);
                              return;
                            }
                            Navigator.pop(context);
                            onSelect(s);
                          },
                          child: Row(children: [
                            _FlagBadge(
                              countryCode: (s['country'] as String?) ??
                                  configService.countryCodeForServer(
                                      s['name'] as String),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(s['name'] as String,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Rajdhani',
                                        color: s['supported'] == false
                                            ? AppColors.darkTextSub
                                            : s['name'] == currentName
                                                ? AppColors.connected
                                                : AppColors.darkText))),
                            if (s['supported'] == false)
                              const Text('XHTTP',
                                  style: TextStyle(
                                      color: AppColors.darkTextSub,
                                      fontSize: 10,
                                      fontFamily: 'SpaceMono'))
                            else if (s['name'] == currentName)
                              const Icon(Icons.check_rounded,
                                  color: AppColors.connected, size: 18)
                            else
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.darkTextSub, size: 18),
                          ]),
                        ),
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
