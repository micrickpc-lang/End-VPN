import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_singbox_vpn/flutter_singbox.dart';
import 'package:dio/dio.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:endvpn/core/services/remnawave_service.dart';
import 'package:endvpn/core/services/vpn_tile_service.dart';
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

  bool isConnected = false;
  bool isConnecting = false;
  String? singboxConfig;
  List<Map<String, dynamic>> servers = [];
  String serverLocation = '';

  final _statusController  = StreamController<Map<String, dynamic>>.broadcast();
  final _trafficController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get statusStream  => _statusController.stream;
  Stream<Map<String, dynamic>> get trafficStream => _trafficController.stream;

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    singbox.onStatusChanged.listen((status) {
      final s = (status['status'] as String? ?? '').toLowerCase();
      if (s == 'started' || s == 'connected') {
        isConnected = true; isConnecting = false;
      } else if (s == 'stopped' || s == 'disconnected') {
        isConnected = false; isConnecting = false;
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
    singboxConfig = config;
    await _storage.write(key: _keyConfig, value: config);
  }

  Future<String?> loadCachedConfig() async {
    singboxConfig ??= await _storage.read(key: _keyConfig);
    return singboxConfig;
  }

  Future<void> saveSubUrl(String url) => _storage.write(key: _keySubUrl, value: url);
  Future<String?> loadSubUrl() => _storage.read(key: _keySubUrl);
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

  bool _isConnected  = false;
  bool _isConnecting = false;
  bool _isDataLoading = true;
  String _statusText    = 'ОТКЛЮЧЕНО';
  String _uploadSpeed   = '--';
  String _downloadSpeed = '--';
  String _ping          = '--';
  Timer? _pingTimer;

  Timer? _trafficDebounce;
  String _pendingDown = '--';
  String _pendingUp   = '--';

  StreamSubscription? _statusSub;
  StreamSubscription? _trafficSub;

  String _formatSpeed(dynamic raw) {
    if (raw == null) return '0 B/s';
    int bytes = 0;
    if (raw is int) bytes = raw;
    else if (raw is double) bytes = raw.toInt();
    else if (raw is String) {
      if (raw.contains('/s')) return raw;
      bytes = int.tryParse(raw) ?? 0;
    } else return '0 B/s';
    if (bytes <= 0) return '0 B/s';
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }

  Future<void> _measurePing() async {
    if (!_isConnected || !mounted) return;
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect('1.1.1.1', 80, timeout: const Duration(seconds: 3));
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
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _measurePing());
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
    if (mounted) setState(() => _ping = '--');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 3));
    _connectController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _vpn.init();
    AdService().init();

    VpnTileService.instance.init();
    VpnTileService.instance.onTileConnect    = () => _toggleConnection();
    VpnTileService.instance.onTileDisconnect = () => _vpn.singbox.stopVPN();

    _isConnected  = _vpn.isConnected;
    _isConnecting = _vpn.isConnecting;
    _statusText   = _isConnected ? 'ПОДКЛЮЧЕНО' : _isConnecting ? 'ПОДКЛЮЧЕНИЕ...' : 'ОТКЛЮЧЕНО';

    if (_isConnected) {
      _connectController.value = 1.0;
      _pulseController.repeat(reverse: true);
      _startPingTimer();
    }

    _statusSub = _vpn.statusStream.listen((status) {
      if (!mounted) return;
      final s = (status['status'] as String? ?? '').toLowerCase();
      setState(() {
        if (s == 'started' || s == 'connected') {
          _isConnected = true; _isConnecting = false;
          _statusText  = 'ПОДКЛЮЧЕНО';
          _connectController.forward();
          _pulseController.repeat(reverse: true);
          _startPingTimer();
          VpnTileService.instance.updateState(connected: true, serverName: _vpn.serverLocation);
        } else if (s == 'stopped' || s == 'disconnected') {
          _isConnected   = false; _isConnecting = false;
          _statusText    = 'ОТКЛЮЧЕНО';
          _uploadSpeed   = '--'; _downloadSpeed = '--';
          _connectController.reverse();
          _pulseController.stop(); _pulseController.value = 0;
          _stopPingTimer();
          VpnTileService.instance.updateState(connected: false);
        } else if (s == 'starting' || s == 'connecting') {
          _isConnecting = true; _statusText = 'ПОДКЛЮЧЕНИЕ...';
        }
      });
    });

    _trafficSub = _vpn.trafficStream.listen((stats) {
      if (!mounted) return;
      _pendingDown = _formatSpeed(stats['downlinkSpeed'] ?? stats['formattedDownlinkSpeed'] ?? 0);
      _pendingUp   = _formatSpeed(stats['uplinkSpeed']   ?? stats['formattedUplinkSpeed']   ?? 0);
      _trafficDebounce ??= Timer(const Duration(seconds: 1), () {
        _trafficDebounce = null;
        if (!mounted) return;
        if (_pendingDown != _downloadSpeed || _pendingUp != _uploadSpeed) {
          setState(() { _downloadSpeed = _pendingDown; _uploadSpeed = _pendingUp; });
        }
      });
    });

    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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
    if (_vpn.singboxConfig != null && mounted) {
      setState(() => _isDataLoading = false);
    }

    try {
      RemnawaveService().init();
      final tgIdStr = await RemnawaveService().getSavedTgId();
      UserModel user;
      if (tgIdStr != null) {
        user = await RemnawaveService().getOrCreateUserByTgId(int.parse(tgIdStr));
      } else {
        user = await RemnawaveService().getOrCreateAnonUser();
      }

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
    }
  }

  Map<String, dynamic>? _clashProxyToSingboxOutbound(Map proxy) {
    try {
      if (proxy['type'] != 'vless') return null;
      final tag     = proxy['name']?.toString() ?? 'proxy';
      final server  = proxy['server']?.toString() ?? '';
      final port    = proxy['port'] as int? ?? 443;
      final uuid    = proxy['uuid']?.toString() ?? '';
      final flow    = proxy['flow']?.toString() ?? '';
      final network = proxy['network']?.toString() ?? 'tcp';

      final outbound = <String, dynamic>{
        'type': 'vless', 'tag': tag,
        'server': server, 'server_port': port,
        'uuid': uuid, 'packet_encoding': 'xudp',
      };

      if (flow.isNotEmpty) outbound['flow'] = flow;

      final reality = proxy['reality-opts'];
      if (reality != null) {
        outbound['tls'] = {
          'enabled': true,
          'server_name': proxy['servername']?.toString() ?? 'www.microsoft.com',
          'utls': {
            'enabled': true,
            'fingerprint': proxy['client-fingerprint']?.toString() ?? 'chrome',
          },
          'reality': {
            'enabled': true,
            'public_key': reality['public-key']?.toString() ?? '',
            'short_id': reality['short-id']?.toString() ?? '',
          },
        };
      } else if (proxy['tls'] == true) {
        outbound['tls'] = {
          'enabled': true,
          'server_name': proxy['servername']?.toString() ?? server,
        };
      }

      if (network == 'ws') {
        final wsOpts = proxy['ws-opts'] as Map? ?? {};
        outbound['transport'] = {
          'type': 'ws',
          'path': wsOpts['path']?.toString() ?? '/',
          'headers': wsOpts['headers'] ?? {},
        };
      } else if (network == 'grpc') {
        final grpcOpts = proxy['grpc-opts'] as Map? ?? {};
        outbound['transport'] = {
          'type': 'grpc',
          'service_name': grpcOpts['grpc-service-name']?.toString() ?? '',
        };
      }

      return outbound;
    } catch (_) { return null; }
  }

  String _buildSingboxConfig(List<Map<String, dynamic>> outbounds, String selectedTag) {
    const directDomains = [
      '.ru', '.xn--p1ai', '.su',
      'vk.com', 'vk.me', 'vk.ru', 'vkontakte.ru',
      'userapi.com', 'vkvideo.ru', 'vkuseraudio.net',
      'vkplay.ru', 'vkplaylive.ru',
      'yandex.ru', 'yandex.com', 'yandex.net', 'yandex.kz', 'yandex.by',
      'yastatic.net', 'yandex-team.ru', 'yadi.sk', 'ya.ru',
      'kinopoisk.ru', 'kinopoisk.com',
      'avito.ru', 'avito.st',
      'mail.ru', 'inbox.ru', 'bk.ru', 'list.ru',
      'ok.ru',
      'sberbank.ru', 'sber.ru', 'sberpay.ru',
      'tbank.ru', 'tinkoff.ru',
      'alfabank.ru', 'vtb.ru', 'raiffeisen.ru',
      'gosuslugi.ru', 'mos.ru', 'nalog.ru', 'pfr.gov.ru',
      'wildberries.ru', 'wb.ru', 'ozon.ru',
      'rustore.ru',
    ];

    const yandexIpRanges = [
      '5.45.192.0/18', '5.255.192.0/18', '37.9.64.0/18',
      '37.140.128.0/18', '77.88.0.0/18', '84.201.128.0/18',
      '87.250.224.0/19', '93.158.128.0/18', '95.108.128.0/17',
      '141.8.128.0/18', '178.154.128.0/18', '213.180.192.0/18',
      '2a02:6b8::/32',
    ];

    final config = {
      'log': {'level': 'warn', 'timestamp': false},
      'dns': {
        'servers': [
          {'tag': 'local', 'address': '223.5.5.5', 'detour': 'direct'},
          {'tag': 'remote', 'address': 'https://1.1.1.1/dns-query', 'detour': selectedTag},
          {'tag': 'local-fallback', 'address': '8.8.4.4', 'detour': 'direct'},
        ],
        'rules': [
          {'domain_suffix': directDomains, 'server': 'local'},
        ],
        'strategy': 'prefer_ipv4',
        'final': 'remote',
        'independent_cache': true,
        'reverse_mapping': true,
      },
      'inbounds': [
        {
          'type': 'tun', 'tag': 'tun-in',
          'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
          'mtu': 1500, 'auto_route': true, 'strict_route': false,
          'stack': 'system', 'sniff': true,
          'sniff_override_destination': false, 'udp_timeout': '300s',
        }
      ],
      'outbounds': [
        ...outbounds,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block',  'tag': 'block'},
        {'type': 'dns',    'tag': 'dns-out'},
        {
          'type': 'selector', 'tag': 'proxy',
          'outbounds': outbounds.map((o) => o['tag'] as String).toList(),
          'default': selectedTag,
        },
      ],
      'route': {
        'rules': [
          {'protocol': 'dns', 'outbound': 'dns-out'},
          {
            'ip_cidr': [
              '0.0.0.0/8', '127.0.0.0/8', '10.0.0.0/8',
              '172.16.0.0/12', '192.168.0.0/16', '100.64.0.0/10',
              '169.254.0.0/16', '240.0.0.0/4', 'fc00::/7',
              'fe80::/10', '::1/128',
            ],
            'outbound': 'direct',
          },
          {'ip_cidr': yandexIpRanges, 'outbound': 'direct'},
          {'domain_suffix': directDomains, 'outbound': 'direct'},
          {'protocol': 'bittorrent', 'outbound': 'direct'},
        ],
        'final': 'proxy',
        'auto_detect_interface': true,
        'find_process': false,
      },
    };
    return jsonEncode(config);
  }

  Future<void> _fetchSubscription(String subUrl) async {
    if (subUrl.isEmpty) return;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final resp = await dio.get(subUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: {'User-Agent': 'clash-meta', 'Accept': 'text/plain, application/yaml, */*'},
          ));

      final yaml    = loadYaml((resp.data as String).trim());
      final proxies = yaml['proxies'] as YamlList?;
      if (proxies == null || proxies.isEmpty) return;

      final outbounds  = <Map<String, dynamic>>[];
      final serverList = <Map<String, dynamic>>[];

      for (final proxy in proxies) {
        final outbound = _clashProxyToSingboxOutbound(proxy as Map);
        if (outbound != null) {
          outbounds.add(outbound);
          serverList.add({
            'name': proxy['name']?.toString() ?? 'Server',
            'tag':  outbound['tag'] as String,
          });
        }
      }
      if (outbounds.isEmpty) return;

      final currentTag = _vpn.servers
          .firstWhere((s) => s['name'] == _vpn.serverLocation, orElse: () => {})['tag'] as String?;
      final selectedTag = (currentTag != null && serverList.any((s) => s['tag'] == currentTag))
          ? currentTag
          : outbounds.first['tag'] as String;

      final config = _buildSingboxConfig(outbounds, selectedTag);
      await _vpn.saveConfig(config);

      if (mounted) {
        setState(() {
          _vpn.servers = serverList;
          if (_vpn.serverLocation.isEmpty ||
              !serverList.any((s) => s['name'] == _vpn.serverLocation)) {
            _vpn.serverLocation = serverList.first['name'] as String;
          }
        });
      }
    } catch (e) {
      debugPrint('Fetch subscription error: $e');
    }
  }

Future<bool> _checkIsPremium() async {
  try {
    final tgIdStr = await RemnawaveService().getSavedTgId();
    UserModel user;
    if (tgIdStr != null) {
      user = await RemnawaveService().getOrCreateUserByTgId(int.parse(tgIdStr));
    } else {
      user = await RemnawaveService().getOrCreateAnonUser();
    }
    return user.subscriptionType == 'paid';
  } catch (e) {
    debugPrint('checkIsPremium error: $e');
    return true; // При ошибке считаем премиум — лучше не показать рекламу, чем показать платнику
  }
}

  Future<void> _toggleConnection() async {
    if (_isConnecting) return;

    if (_isConnected) {
      final isPremium = await _checkIsPremium();
      if (!isPremium) {
        await AdService().showRewardedAd(context);
      }
      await _vpn.singbox.stopVPN();
      return;
    }

    if (_vpn.singboxConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Нет конфигурации VPN — проверьте соединение'),
          backgroundColor: AppColors.crimson));
      return;
    }

    final isPremium = await _checkIsPremium();
    if (!isPremium) {
      final watched = await AdService().showRewardedAd(context);
      if (!watched) return;
    }

    setState(() { _isConnecting = true; _statusText = 'ПОДКЛЮЧЕНИЕ...'; });
    _connectController.forward();
    try {
      await _vpn.singbox.saveConfig(_vpn.singboxConfig!);
      final ok = await _vpn.singbox.startVPN();
      if (!ok && mounted) {
        setState(() { _isConnecting = false; _statusText = 'ОШИБКА'; });
        _connectController.reverse();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ошибка запуска VPN'), backgroundColor: AppColors.crimson));
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isConnecting = false; _statusText = 'ОШИБКА'; });
        _connectController.reverse();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ошибка: $e'), backgroundColor: AppColors.crimson));
      }
    }
  }

  Future<void> _selectServer(Map<String, dynamic> server) async {
    if (_vpn.singboxConfig == null) return;
    final config    = jsonDecode(_vpn.singboxConfig!) as Map<String, dynamic>;
    final outbounds = (config['outbounds'] as List)
        .where((o) => !['direct', 'block', 'dns-out', 'proxy'].contains((o as Map)['tag']))
        .map((o) => Map<String, dynamic>.from(o as Map))
        .toList();
    final newConfig = _buildSingboxConfig(outbounds, server['tag'] as String);
    await _vpn.saveConfig(newConfig);
    setState(() => _vpn.serverLocation = server['name'] as String);
    VpnTileService.instance.updateServerName(server['name'] as String);

    if (_isConnected) {
      setState(() { _isConnecting = true; _statusText = 'СМЕНА СЕРВЕРА...'; });
      try {
        await _vpn.singbox.stopVPN();
        await Future.delayed(const Duration(milliseconds: 800));
        await _vpn.singbox.saveConfig(newConfig);
        await _vpn.singbox.startVPN();
      } catch (e) {
        if (mounted) {
          setState(() { _isConnecting = false; _statusText = 'ОШИБКА'; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Ошибка смены сервера: $e'), backgroundColor: AppColors.crimson));
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pingTimer?.cancel();
    _trafficDebounce?.cancel();
    _statusSub?.cancel();
    _trafficSub?.cancel();
    _pulseController.dispose();
    _connectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          const _StaticBackground(),
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
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/images/logo.png', width: 36, height: 36, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        const Text('END VPN', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20,
            fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 3)),
        const Spacer(),
        if (_isDataLoading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 1.5)),
          ),
        GlassCard(
          borderRadius: 14, padding: const EdgeInsets.all(10),
          child: const Icon(Icons.notifications_none_rounded, color: AppColors.darkText, size: 20),
        ),
      ]),
    );
  }

  Widget _buildServerSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        onTap: _showServerSheet,
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
            ),
            child: const Icon(Icons.location_on_rounded, color: AppColors.neonBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('СЕРВЕР', style: TextStyle(fontSize: 10, fontFamily: 'SpaceMono',
                color: AppColors.darkTextSub, letterSpacing: 2)),
            Text(_vpn.serverLocation.isEmpty ? 'Загрузка...' : _vpn.serverLocation,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: AppColors.darkText, fontFamily: 'Rajdhani')),
          ])),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected ? AppColors.connected : AppColors.darkTextSub,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.darkTextSub, size: 20),
        ]),
      ),
    );
  }

  Widget _buildConnectButton(Size size) {
    return GestureDetector(
      onTap: _toggleConnection,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _connectController]),
        builder: (context, child) {
          final pulse = _isConnected ? 1.0 + (_pulseController.value * 0.03) : 1.0;
          final Color primaryColor = _isConnecting
              ? Color.lerp(AppColors.neonBlue, AppColors.warning, _connectController.value)!
              : _isConnected ? AppColors.connected : AppColors.darkTextSub;

          return Transform.scale(
            scale: pulse,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isConnected)
                  Container(
                    width: 215, height: 215,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.connected.withOpacity(0.12 * _pulseController.value),
                        width: 1,
                      ),
                    ),
                  ),
                Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 40, spreadRadius: 4),
                    ],
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            primaryColor.withOpacity(0.25),
                            primaryColor.withOpacity(0.05),
                          ]),
                          border: Border.all(color: primaryColor.withOpacity(0.5), width: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isConnecting)
                              const SizedBox(width: 36, height: 36,
                                  child: CircularProgressIndicator(
                                      color: AppColors.warning, strokeWidth: 2))
                            else
                              Icon(Icons.power_settings_new_rounded, size: 52, color: primaryColor),
                            const SizedBox(height: 8),
                            Text(_statusText, style: TextStyle(
                                fontSize: 11, fontFamily: 'SpaceMono',
                                fontWeight: FontWeight.w700,
                                color: primaryColor, letterSpacing: 2)),
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
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Expanded(child: _StatCard(icon: Icons.timer_rounded, label: 'ПИНГ',
            value: _isConnected ? _ping : '--', color: AppColors.neonBlue)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(icon: Icons.arrow_downward_rounded, label: 'СКАЧАТЬ',
            value: _isConnected ? _downloadSpeed : '--', color: AppColors.connected)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(icon: Icons.arrow_upward_rounded, label: 'ЗАГРУЗИТЬ',
            value: _isConnected ? _uploadSpeed : '--', color: AppColors.crimson)),
      ]).animate(delay: 300.ms).fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
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
          onSelect: _selectServer),
    );
  }
}

class _StaticBackground extends StatelessWidget {
  const _StaticBackground();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: MediaQuery.of(context).size, painter: _StaticMeshPainter());
}

class _StaticMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.2), size.width * 0.55,
        Paint()..shader = RadialGradient(
                colors: [AppColors.neonBlue.withOpacity(0.10), Colors.transparent])
            .createShader(Rect.fromCircle(
                center: Offset(size.width * 0.7, size.height * 0.2),
                radius: size.width * 0.55)));
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.75), size.width * 0.45,
        Paint()..shader = RadialGradient(
                colors: [AppColors.crimson.withOpacity(0.07), Colors.transparent])
            .createShader(Rect.fromCircle(
                center: Offset(size.width * 0.3, size.height * 0.75),
                radius: size.width * 0.45)));
  }
  @override
  bool shouldRepaint(_) => false;
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 9, fontFamily: 'SpaceMono',
            color: AppColors.darkTextSub, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontFamily: 'SpaceMono',
                fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _ServerSelectSheet extends StatelessWidget {
  final List<Map<String, dynamic>> servers;
  final String currentName;
  final Future<void> Function(Map<String, dynamic>) onSelect;
  const _ServerSelectSheet({required this.servers, required this.currentName, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F20),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0xFF1E1E40), width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: const Color(0xFF1E1E40),
                        borderRadius: BorderRadius.circular(2)))),
                const Text('ВЫБОР СЕРВЕРА', style: TextStyle(
                    fontSize: 13, fontFamily: 'SpaceMono', fontWeight: FontWeight.w700,
                    color: AppColors.darkTextSub, letterSpacing: 2)),
                const SizedBox(height: 16),
                if (servers.isEmpty)
                  const Center(child: Text('Серверы не найдены',
                      style: TextStyle(color: AppColors.darkTextSub)))
                else
                  ...servers.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          onTap: () { Navigator.pop(context); onSelect(s); },
                          child: Row(children: [
                            Icon(Icons.public_rounded,
                                color: s['name'] == currentName
                                    ? AppColors.connected : AppColors.neonBlue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(s['name'] as String,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                                    fontFamily: 'Rajdhani',
                                    color: s['name'] == currentName
                                        ? AppColors.connected : AppColors.darkText))),
                            if (s['name'] == currentName)
                              const Icon(Icons.check_rounded, color: AppColors.connected, size: 18)
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