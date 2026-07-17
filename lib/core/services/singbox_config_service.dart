import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'package:endvpn/core/models/vpn_server.dart';

enum SingboxConfigTarget { desktop, native }

class SingboxSubscriptionResult {
  final List<Map<String, dynamic>> outbounds;
  final List<VpnServer> servers;
  final String selectedTag;
  final String configJson;

  const SingboxSubscriptionResult({
    required this.outbounds,
    required this.servers,
    required this.selectedTag,
    required this.configJson,
  });
}

class SingboxConfigService {
  static const _serviceTags = {'direct', 'block', 'proxy', 'dns-out'};

  String buildFromSubscription(
    String body, {
    String? currentTag,
    SingboxConfigTarget target = SingboxConfigTarget.desktop,
  }) {
    final outbounds = parseSubscriptionOutbounds(body);
    if (outbounds.isEmpty) return '';

    final selectedTag = _selectTag(outbounds, currentTag);
    return buildConfig(outbounds, selectedTag, target: target);
  }

  SingboxSubscriptionResult parseSubscription(
    String body, {
    String? currentTag,
    SingboxConfigTarget target = SingboxConfigTarget.desktop,
  }) {
    final decodedBody = _decodeSubscriptionBody(body);
    final outbounds = parseSubscriptionOutbounds(decodedBody);
    final servers = _subscriptionServers(decodedBody, outbounds);
    if (outbounds.isEmpty) {
      return SingboxSubscriptionResult(
        outbounds: const [],
        servers: servers,
        selectedTag: servers.isEmpty ? '' : servers.first.tag,
        configJson: jsonEncode({'outbounds': <dynamic>[]}),
      );
    }

    final selectedTag = _selectTag(outbounds, currentTag);
    return SingboxSubscriptionResult(
      outbounds: outbounds,
      servers: servers,
      selectedTag: selectedTag,
      configJson: buildConfig(outbounds, selectedTag, target: target),
    );
  }

  List<Map<String, dynamic>> parseSubscriptionOutbounds(String rawBody) {
    final body = _decodeSubscriptionBody(rawBody);
    final clashOutbounds = _parseClashOutbounds(body);
    if (clashOutbounds.isNotEmpty) return clashOutbounds;
    return _parseVlessUriOutbounds(body);
  }

  List<Map<String, dynamic>> userOutboundsFromConfig(String configJson) {
    final config =
        jsonDecode(upgradeConfig(configJson)) as Map<String, dynamic>;
    final outbounds = (config['outbounds'] as List?) ?? const [];
    return outbounds
        .whereType<Map>()
        .where(
            (outbound) => !_serviceTags.contains(outbound['tag']?.toString()))
        .map((outbound) => Map<String, dynamic>.from(outbound))
        .toList(growable: false);
  }

  VpnServer serverFromOutbound(Map<String, dynamic> outbound) {
    final tag = outbound['tag']?.toString() ?? 'Server';
    return VpnServer(
        name: tag, tag: tag, countryCode: countryCodeForServer(tag));
  }

  List<VpnServer> _subscriptionServers(
    String body,
    List<Map<String, dynamic>> supportedOutbounds,
  ) {
    final supportedTags = supportedOutbounds
        .map((outbound) => outbound['tag']?.toString())
        .whereType<String>()
        .toSet();
    final names = <String>[];
    final xrayConfigs = <String, String>{};

    try {
      final yaml = loadYaml(body);
      if (yaml is YamlMap && yaml['proxies'] is YamlList) {
        for (final proxy in yaml['proxies'] as YamlList) {
          if (proxy is Map && proxy['type'] == 'vless') {
            final name = cleanServerName(proxy['name']?.toString() ?? 'Server');
            names.add(name);
            if (proxy['network']?.toString() == 'xhttp') {
              xrayConfigs[name] = _buildXrayConfigFromClash(proxy);
            }
          }
        }
      }
    } catch (_) {}

    if (names.isEmpty) {
      for (final line in const LineSplitter().convert(body)) {
        final value = line.trim();
        if (!value.startsWith('vless://')) continue;
        try {
          final uri = Uri.parse(value);
          names.add(cleanServerName(Uri.decodeComponent(
            uri.fragment.isNotEmpty ? uri.fragment : uri.host,
          )));
          final name = names.last;
          if (uri.queryParameters['type'] == 'xhttp') {
            xrayConfigs[name] = _buildXrayConfig(uri);
          }
        } catch (_) {}
      }
    }

    if (names.isEmpty) {
      return supportedOutbounds.map(serverFromOutbound).toList(growable: false);
    }

    return names.toSet().map((name) {
      return VpnServer(
        name: name,
        tag: name,
        countryCode: countryCodeForServer(name),
        supported:
            supportedTags.contains(name) || xrayConfigs.containsKey(name),
        xrayConfig: xrayConfigs[name],
      );
    }).toList(growable: false);
  }

  String _buildXrayConfig(Uri uri) {
    final params = uri.queryParameters;
    final user = <String, dynamic>{
      'id': uri.userInfo,
      'encryption': params['encryption'] ?? 'none',
      'level': 0,
    };
    if ((params['flow'] ?? '').isNotEmpty) user['flow'] = params['flow'];
    final stream = <String, dynamic>{
      'network': 'xhttp',
      'security': params['security'] ?? 'reality',
      'xhttpSettings': {
        'host': params['host'] ?? '',
        'path': params['path'] ?? '/',
        'mode': params['mode'] ?? 'auto',
      },
    };
    if (params['security'] == 'reality') {
      stream['realitySettings'] = {
        'serverName': params['sni'] ?? uri.host,
        'fingerprint': params['fp'] ?? 'chrome',
        'publicKey': params['pbk'] ?? '',
        'shortId': params['sid'] ?? '',
        'spiderX': params['spx'] ?? '/',
      };
    }
    return jsonEncode({
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'tun',
          'protocol': 'tun',
          'settings': {'name': 'xray0', 'MTU': 1400, 'userLevel': 0},
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls', 'quic'],
          },
        }
      ],
      'outbounds': [
        {
          'tag': 'proxy',
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {
                'address': uri.host,
                'port': uri.hasPort ? uri.port : 443,
                'users': [user],
              }
            ],
          },
          'streamSettings': stream,
        },
        {'tag': 'direct', 'protocol': 'freedom'},
        {'tag': 'block', 'protocol': 'blackhole'},
      ],
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [],
      },
      'dns': {
        'servers': ['1.1.1.1', '8.8.8.8'],
      },
    });
  }

  String _buildXrayConfigFromClash(Map proxy) {
    final reality = proxy['reality-opts'] as Map? ?? const {};
    final xhttp = proxy['xhttp-opts'] as Map? ?? const {};
    return _buildXrayConfig(Uri(
      scheme: 'vless',
      userInfo: proxy['uuid']?.toString() ?? '',
      host: proxy['server']?.toString() ?? '',
      port: int.tryParse(proxy['port']?.toString() ?? '') ?? 443,
      queryParameters: {
        'type': 'xhttp',
        'security':
            proxy['tls'] == true || reality.isNotEmpty ? 'reality' : 'none',
        'sni': proxy['servername']?.toString() ?? '',
        'fp': proxy['client-fingerprint']?.toString() ?? 'chrome',
        'pbk': reality['public-key']?.toString() ?? '',
        'sid': reality['short-id']?.toString() ?? '',
        'host': xhttp['host']?.toString() ?? '',
        'path': xhttp['path']?.toString() ?? '/',
        'mode': xhttp['mode']?.toString() ?? 'auto',
        'flow': proxy['flow']?.toString() ?? '',
      },
      fragment: proxy['name']?.toString() ?? '',
    ));
  }

  String rebuildConfig(
    String rawConfig,
    String selectedTag, {
    SingboxConfigTarget target = SingboxConfigTarget.desktop,
  }) {
    final outbounds = userOutboundsFromConfig(rawConfig);
    if (outbounds.isEmpty) {
      return target == SingboxConfigTarget.desktop
          ? upgradeConfig(rawConfig)
          : rawConfig;
    }
    final effectiveTag =
        outbounds.any((outbound) => outbound['tag'] == selectedTag)
            ? selectedTag
            : outbounds.first['tag'] as String;
    return buildConfig(outbounds, effectiveTag, target: target);
  }

  String buildConfig(
    List<Map<String, dynamic>> outbounds,
    String selectedTag, {
    SingboxConfigTarget target = SingboxConfigTarget.desktop,
  }) {
    final config = target == SingboxConfigTarget.native
        ? _buildNativeConfig(outbounds, selectedTag)
        : _buildDesktopConfig(outbounds, selectedTag);
    final encoded = jsonEncode(config);
    return target == SingboxConfigTarget.desktop
        ? upgradeConfig(encoded)
        : encoded;
  }

  Map<String, dynamic> _buildDesktopConfig(
    List<Map<String, dynamic>> outbounds,
    String selectedTag,
  ) {
    final config = {
      'log': {'level': 'warn', 'timestamp': false},
      'dns': {
        'servers': [
          {
            'type': 'udp',
            'tag': 'local',
            'server': '223.5.5.5',
          },
          {
            'type': 'https',
            'tag': 'remote',
            'server': '1.1.1.1',
            'path': '/dns-query',
            'detour': selectedTag,
          },
          {
            'type': 'udp',
            'tag': 'local-fallback',
            'server': '8.8.4.4',
          },
        ],
        'rules': [
          {'domain_suffix': _directDomains, 'server': 'local'},
        ],
        'strategy': 'prefer_ipv4',
        'final': 'remote',
        'independent_cache': true,
        'reverse_mapping': true,
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'EndVPN',
          'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
          'mtu': 1500,
          'auto_route': true,
          'strict_route': false,
          'stack': 'system',
          'udp_timeout': '300s',
        }
      ],
      'outbounds': [
        ...outbounds,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
        {
          'type': 'selector',
          'tag': 'proxy',
          'outbounds':
              outbounds.map((outbound) => outbound['tag'] as String).toList(),
          'default': selectedTag,
        },
      ],
      'route': {
        'rules': [
          {'protocol': 'dns', 'action': 'hijack-dns'},
          {'ip_cidr': _privateIpRanges, 'outbound': 'direct'},
          {'ip_cidr': _yandexIpRanges, 'outbound': 'direct'},
          {'domain_suffix': _directDomains, 'outbound': 'direct'},
          {'protocol': 'bittorrent', 'outbound': 'direct'},
        ],
        'final': 'proxy',
        'default_domain_resolver': 'local',
        'auto_detect_interface': true,
        'find_process': false,
      },
    };
    return config;
  }

  Map<String, dynamic> _buildNativeConfig(
    List<Map<String, dynamic>> outbounds,
    String selectedTag,
  ) {
    return {
      'log': {'level': 'warn', 'timestamp': false},
      'dns': {
        'servers': [
          {
            'tag': 'proxy-dns',
            'address': 'tls://8.8.8.8',
            'detour': 'proxy',
          },
          {
            'tag': 'local-dns',
            'address': 'udp://1.1.1.1',
            'detour': 'direct',
          },
        ],
        'rules': [
          {'domain_suffix': _directDomains, 'server': 'local-dns'},
        ],
        'strategy': 'prefer_ipv4',
        'final': 'local-dns',
        'independent_cache': true,
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'tun0',
          'inet4_address': '172.19.0.1/30',
          'mtu': 1400,
          'auto_route': true,
          'strict_route': true,
          'stack': 'mixed',
          'sniff': true,
          'sniff_override_destination': false,
          'domain_strategy': 'ipv4_only',
        }
      ],
      'outbounds': [
        ...outbounds,
        {'type': 'dns', 'tag': 'dns-out'},
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
        {
          'type': 'selector',
          'tag': 'proxy',
          'outbounds':
              outbounds.map((outbound) => outbound['tag'] as String).toList(),
          'default': selectedTag,
        },
      ],
      'route': {
        'rules': [
          {'protocol': 'dns', 'outbound': 'dns-out'},
          {'ip_cidr': _privateIpRanges, 'outbound': 'direct'},
          {'ip_cidr': _yandexIpRanges, 'outbound': 'direct'},
          {'domain_suffix': _directDomains, 'outbound': 'direct'},
          {'protocol': 'bittorrent', 'outbound': 'direct'},
        ],
        'final': 'proxy',
        'auto_detect_interface': true,
      },
    };
  }

  String buildXraySocksConfig(String rawXrayConfig, {int socksPort = 17890}) {
    final xrayConfig = jsonDecode(rawXrayConfig) as Map<String, dynamic>;
    xrayConfig['inbounds'] = [
      {
        'tag': 'local-socks',
        'listen': '127.0.0.1',
        'port': socksPort,
        'protocol': 'socks',
        'settings': {'udp': true},
        'sniffing': {
          'enabled': true,
          'destOverride': ['http', 'tls', 'quic'],
        },
      }
    ];
    return jsonEncode(xrayConfig);
  }

  String buildXrayBridgeConfig(String rawXrayConfig, {int socksPort = 17890}) {
    final serverAddress = _xrayServerAddress(rawXrayConfig);
    return jsonEncode({
      'log': {'level': 'warn'},
      'dns': {
        'servers': [
          {
            'type': 'udp',
            'tag': 'remote-dns',
            'server': '1.1.1.1',
            'detour': 'proxy',
          },
          {'type': 'udp', 'tag': 'direct-dns', 'server': '223.5.5.5'},
        ],
        'final': 'remote-dns',
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'EndVPN',
          'address': ['172.19.0.1/30'],
          'mtu': 1500,
          'auto_route': true,
          'strict_route': false,
          'stack': 'system',
        }
      ],
      'outbounds': [
        {
          'type': 'socks',
          'tag': 'proxy',
          'server': '127.0.0.1',
          'server_port': socksPort,
        },
        {'type': 'direct', 'tag': 'direct'},
      ],
      'route': {
        'rules': [
          // Exclude the companion xray.exe process from the tunnel: without
          // this, TUN auto_route captures xray's own upstream connection to
          // the VPS and loops it back through the socks outbound forever.
          {'process_name': 'xray.exe', 'outbound': 'direct'},
          {'protocol': 'dns', 'action': 'hijack-dns'},
          if (serverAddress != null) _directRuleForHost(serverAddress),
          {'ip_cidr': _privateIpRanges, 'outbound': 'direct'},
        ],
        'final': 'proxy',
        'default_domain_resolver': 'direct-dns',
        'auto_detect_interface': true,
      },
    });
  }

  String? _xrayServerAddress(String rawXrayConfig) {
    try {
      final config = jsonDecode(rawXrayConfig) as Map<String, dynamic>;
      final outbounds = (config['outbounds'] as List?) ?? const [];
      for (final outbound in outbounds) {
        if (outbound is! Map) continue;
        final vnext =
            ((outbound['settings'] as Map?)?['vnext'] as List?) ?? const [];
        for (final entry in vnext) {
          final address = (entry as Map?)?['address']?.toString();
          if (address != null && address.isNotEmpty) return address;
        }
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _directRuleForHost(String host) {
    final isIpv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
    if (isIpv4) {
      return {
        'ip_cidr': ['$host/32'],
        'outbound': 'direct',
      };
    }
    if (host.contains(':')) {
      return {
        'ip_cidr': ['$host/128'],
        'outbound': 'direct',
      };
    }
    return {
      'domain': [host],
      'outbound': 'direct',
    };
  }

  String upgradeConfig(String rawConfig) {
    try {
      final config = jsonDecode(rawConfig) as Map<String, dynamic>;
      final tagMap = <String, String>{};
      final outbounds = config['outbounds'];

      if (outbounds is List) {
        outbounds.removeWhere((outbound) =>
            outbound is Map &&
            (outbound['type'] == 'dns' || outbound['tag'] == 'dns-out'));

        for (final outbound in outbounds) {
          if (outbound is! Map) continue;
          if (outbound['type'] == 'vless') outbound.remove('packet_encoding');

          final oldTag = outbound['tag']?.toString();
          if (oldTag == null || oldTag.isEmpty) continue;
          final newTag = cleanServerName(oldTag);
          tagMap[oldTag] = newTag;
          outbound['tag'] = newTag;
        }

        for (final outbound in outbounds) {
          if (outbound is! Map) continue;
          _rewriteSelector(outbound, tagMap);
        }
      }

      _upgradeDns(config['dns'], tagMap);
      _upgradeInbounds(config['inbounds']);
      _upgradeRoute(config['route'], tagMap);

      return jsonEncode(config);
    } catch (_) {
      return rawConfig;
    }
  }

  String cleanServerName(String value) {
    final repaired =
        _repairMojibake(value).replaceAll(RegExp(r'\s+'), ' ').trim();
    final code =
        _countryCodeFromEmojiFlag(repaired) ?? _leadingCountryCode(repaired);
    final withoutEmoji = repaired
        .replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (code == null || withoutEmoji.toUpperCase().startsWith('$code ')) {
      return withoutEmoji.isEmpty ? repaired : withoutEmoji;
    }
    return '$code $withoutEmoji'.trim();
  }

  String countryCodeForServer(String value) {
    final repaired = _repairMojibake(value);
    final explicit =
        _countryCodeFromEmojiFlag(repaired) ?? _leadingCountryCode(repaired);
    if (explicit != null && _supportedCountries.contains(explicit)) {
      return explicit;
    }

    final text = repaired.toLowerCase();
    for (final entry in _countryMatchers.entries) {
      if (entry.value.any(text.contains)) return entry.key;
    }
    return 'WORLD';
  }

  String flagForServer(String value) {
    final code = countryCodeForServer(value);
    if (code.length != 2) return '🌐';
    return String.fromCharCodes(
      code.codeUnits.map((unit) => 0x1F1A5 + unit),
    );
  }

  String _selectTag(List<Map<String, dynamic>> outbounds, String? currentTag) {
    if (currentTag != null &&
        outbounds.any((outbound) => outbound['tag'] == currentTag)) {
      return currentTag;
    }
    return outbounds.first['tag'] as String;
  }

  List<Map<String, dynamic>> _parseClashOutbounds(String body) {
    try {
      final yaml = loadYaml(body);
      if (yaml is! YamlMap || yaml['proxies'] is! YamlList) return const [];

      return (yaml['proxies'] as YamlList)
          .whereType<Map>()
          .map(_clashProxyToOutbound)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> _parseVlessUriOutbounds(String body) {
    return const LineSplitter()
        .convert(body)
        .map((line) => line.trim())
        .where((line) => line.startsWith('vless://'))
        .map(_vlessUriToOutbound)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Map<String, dynamic>? _clashProxyToOutbound(Map proxy) {
    if (proxy['type'] != 'vless') return null;

    final network = proxy['network']?.toString() ?? 'tcp';
    if (!_supportedTransports.contains(network)) return null;

    final server = proxy['server']?.toString() ?? '';
    final uuid = proxy['uuid']?.toString() ?? '';
    if (server.isEmpty || uuid.isEmpty) return null;

    final outbound = <String, dynamic>{
      'type': 'vless',
      'tag': cleanServerName(proxy['name']?.toString() ?? server),
      'server': server,
      'server_port': int.tryParse(proxy['port']?.toString() ?? '') ?? 443,
      'uuid': uuid,
    };

    _putIfNotEmpty(outbound, 'flow', proxy['flow']?.toString());
    _applyClashTls(outbound, proxy, server);
    _applyClashTransport(outbound, proxy);
    return outbound;
  }

  Map<String, dynamic>? _vlessUriToOutbound(String line) {
    try {
      final uri = Uri.parse(line);
      if (uri.scheme != 'vless' || uri.userInfo.isEmpty || uri.host.isEmpty) {
        return null;
      }

      final params = uri.queryParameters;
      final network = params['type'] ?? 'tcp';
      if (!_supportedTransports.contains(network)) return null;
      final outbound = <String, dynamic>{
        'type': 'vless',
        'tag': cleanServerName(Uri.decodeComponent(
          uri.fragment.isNotEmpty ? uri.fragment : uri.host,
        )),
        'server': uri.host,
        'server_port': uri.hasPort ? uri.port : 443,
        'uuid': uri.userInfo,
      };

      _putIfNotEmpty(outbound, 'flow', params['flow']);
      _applyUriTls(outbound, params, uri.host);
      _applyUriTransport(outbound, params);
      return outbound;
    } catch (_) {
      return null;
    }
  }

  String _decodeSubscriptionBody(String rawBody) {
    final body = rawBody.trim();
    if (body.contains('://') || body.startsWith('proxies:')) return body;

    try {
      final normalized = base64.normalize(body.replaceAll(RegExp(r'\s+'), ''));
      final decoded =
          utf8.decode(base64.decode(normalized), allowMalformed: true).trim();
      if (decoded.contains('://') || decoded.startsWith('proxies:')) {
        return decoded;
      }
    } catch (_) {}

    return body;
  }

  void _applyClashTls(Map<String, dynamic> outbound, Map proxy, String server) {
    final reality = proxy['reality-opts'];
    if (reality is Map) {
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
      return;
    }

    if (proxy['tls'] == true) {
      outbound['tls'] = {
        'enabled': true,
        'server_name': proxy['servername']?.toString() ?? server,
      };
    }
  }

  void _applyUriTls(
    Map<String, dynamic> outbound,
    Map<String, String> params,
    String host,
  ) {
    final security = params['security'] ?? '';
    if (security != 'reality' && security != 'tls') return;

    final tls = <String, dynamic>{
      'enabled': true,
      'server_name': params['sni'] ?? params['serverName'] ?? host,
      'utls': {'enabled': true, 'fingerprint': params['fp'] ?? 'chrome'},
    };

    if (security == 'reality') {
      tls['reality'] = {
        'enabled': true,
        'public_key': params['pbk'] ?? params['publicKey'] ?? '',
        'short_id': params['sid'] ?? params['shortId'] ?? '',
      };
    }

    outbound['tls'] = tls;
  }

  void _applyClashTransport(Map<String, dynamic> outbound, Map proxy) {
    final network = proxy['network']?.toString() ?? 'tcp';
    if (network == 'ws') {
      final wsOpts = proxy['ws-opts'] as Map? ?? const {};
      outbound['transport'] = {
        'type': 'ws',
        'path': wsOpts['path']?.toString() ?? '/',
        'headers': wsOpts['headers'] ?? {},
      };
      return;
    }

    if (network == 'grpc') {
      final grpcOpts = proxy['grpc-opts'] as Map? ?? const {};
      outbound['transport'] = {
        'type': 'grpc',
        'service_name': grpcOpts['grpc-service-name']?.toString() ?? '',
      };
      return;
    }

    if (network == 'http' || network == 'httpupgrade') {
      final httpOpts = proxy['http-opts'] as Map? ??
          proxy['httpupgrade-opts'] as Map? ??
          const {};
      outbound['transport'] = {
        'type': network,
        'path': httpOpts['path']?.toString() ?? '/',
        if (httpOpts['headers'] is Map) 'headers': httpOpts['headers'],
      };
    }
  }

  void _applyUriTransport(
    Map<String, dynamic> outbound,
    Map<String, String> params,
  ) {
    final network = params['type'] ?? 'tcp';
    if (network == 'ws') {
      outbound['transport'] = {
        'type': 'ws',
        'path': params['path'] ?? '/',
        if ((params['host'] ?? '').isNotEmpty)
          'headers': {'Host': params['host']},
      };
      return;
    }

    if (network == 'grpc') {
      outbound['transport'] = {
        'type': 'grpc',
        'service_name': params['serviceName'] ?? params['service_name'] ?? '',
      };
      return;
    }

    if (network == 'http' || network == 'httpupgrade') {
      outbound['transport'] = {
        'type': network,
        'path': params['path'] ?? '/',
        if ((params['host'] ?? '').isNotEmpty)
          'headers': {'Host': params['host']},
      };
    }
  }

  void _rewriteSelector(Map outbound, Map<String, String> tagMap) {
    final selectorOutbounds = outbound['outbounds'];
    if (selectorOutbounds is List) {
      outbound['outbounds'] = selectorOutbounds
          .map((tag) => tagMap[tag?.toString()] ?? tag?.toString())
          .whereType<String>()
          .where((tag) => tag != 'dns-out')
          .toList(growable: false);
    }

    final defaultTag = outbound['default']?.toString();
    if (defaultTag != null) {
      outbound['default'] = tagMap[defaultTag] ?? cleanServerName(defaultTag);
    }
  }

  void _upgradeDns(dynamic dns, Map<String, String> tagMap) {
    if (dns is! Map) return;
    final servers = dns['servers'];
    if (servers is! List) return;

    dns['servers'] = servers.map((server) {
      if (server is! Map) return server;
      final migrated = Map<String, dynamic>.from(server);
      final address = migrated.remove('address')?.toString();

      if (address != null && !migrated.containsKey('server')) {
        final uri = Uri.tryParse(address);
        if (uri != null && uri.scheme == 'https') {
          migrated['type'] = 'https';
          migrated['server'] = uri.host;
          migrated['path'] = uri.path.isEmpty ? '/dns-query' : uri.path;
        } else {
          migrated['type'] = 'udp';
          migrated['server'] = address;
        }
      }

      final detour = migrated['detour']?.toString();
      if (detour != null) {
        if (detour == 'direct' &&
            (migrated['tag'] == 'local' ||
                migrated['tag'] == 'local-fallback')) {
          migrated.remove('detour');
        } else {
          migrated['detour'] = tagMap[detour] ?? cleanServerName(detour);
        }
      }
      return migrated;
    }).toList(growable: false);
  }

  void _upgradeInbounds(dynamic inbounds) {
    if (inbounds is! List) return;
    for (final inbound in inbounds) {
      if (inbound is! Map) continue;
      inbound.remove('sniff');
      inbound.remove('sniff_override_destination');
    }
  }

  void _upgradeRoute(dynamic route, Map<String, String> tagMap) {
    if (route is! Map) return;
    route['default_domain_resolver'] ??= 'local';

    final finalTag = route['final']?.toString();
    if (finalTag != null) route['final'] = tagMap[finalTag] ?? finalTag;

    final rules = route['rules'];
    if (rules is! List) return;
    for (final rule in rules) {
      if (rule is! Map) continue;
      if (rule['protocol'] == 'dns' &&
          (rule['outbound'] == 'dns-out' || !rule.containsKey('action'))) {
        rule.remove('outbound');
        rule['action'] = 'hijack-dns';
      }

      final outbound = rule['outbound']?.toString();
      if (outbound != null) rule['outbound'] = tagMap[outbound] ?? outbound;
    }
  }

  void _putIfNotEmpty(Map<String, dynamic> target, String key, String? value) {
    if (value != null && value.isNotEmpty) target[key] = value;
  }

  String _repairMojibake(String value) {
    var current = value;
    for (var i = 0; i < 3; i++) {
      if (!_looksLikeMojibake(current)) break;
      try {
        final repaired = utf8.decode(latin1.encode(current));
        if (repaired == current) break;
        current = repaired;
      } catch (_) {
        break;
      }
    }
    return current;
  }

  bool _looksLikeMojibake(String value) {
    return value.codeUnits.any((unit) =>
        unit == 0x00D0 ||
        unit == 0x00D1 ||
        unit == 0x00C3 ||
        unit == 0x00C2 ||
        unit == 0x00F0 ||
        unit == 0x00E2);
  }

  String? _countryCodeFromEmojiFlag(String value) {
    final runes = value.runes.toList(growable: false);
    for (var i = 0; i + 1 < runes.length; i++) {
      final first = runes[i];
      final second = runes[i + 1];
      final isFlag = first >= 0x1F1E6 &&
          first <= 0x1F1FF &&
          second >= 0x1F1E6 &&
          second <= 0x1F1FF;
      if (!isFlag) continue;

      return String.fromCharCodes([
        0x41 + first - 0x1F1E6,
        0x41 + second - 0x1F1E6,
      ]);
    }
    return null;
  }

  String? _leadingCountryCode(String value) {
    final match = RegExp(r'^\s*([A-Za-z]{2})\b').firstMatch(value);
    return match?.group(1)?.toUpperCase();
  }

  static const _supportedCountries = {
    'FI',
    'NL',
    'US',
    'DE',
    'FR',
    'GB',
    'RU',
    'LV',
    'LT',
  };

  static const _supportedTransports = {
    'tcp',
    'ws',
    'grpc',
    'http',
    'httpupgrade',
  };

  static const _countryMatchers = {
    'FI': ['fin', '\u0444\u0438\u043d'],
    'NL': ['nether', 'holland', '\u043d\u0438\u0434\u0435\u0440'],
    'US': ['usa', 'united states', 'america', '\u0441\u0448\u0430'],
    'DE': ['germany', '\u0433\u0435\u0440\u043c'],
    'FR': ['france', '\u0444\u0440\u0430\u043d'],
    'GB': ['uk', 'united kingdom', 'britain'],
    'RU': ['russia', '\u0440\u043e\u0441'],
    'LV': ['latvia', '\u043b\u0430\u0442\u0432'],
    'LT': ['lithuania', '\u043b\u0438\u0442\u0432'],
  };

  static const _directDomains = [
    '.ru',
    '.xn--p1ai',
    '.su',
    'vk.com',
    'vk.me',
    'vk.ru',
    'vkontakte.ru',
    'userapi.com',
    'vkvideo.ru',
    'vkuseraudio.net',
    'vkplay.ru',
    'vkplaylive.ru',
    'yandex.ru',
    'yandex.com',
    'yandex.net',
    'yandex.kz',
    'yandex.by',
    'yastatic.net',
    'yandex-team.ru',
    'yadi.sk',
    'ya.ru',
    'kinopoisk.ru',
    'kinopoisk.com',
    'avito.ru',
    'avito.st',
    'mail.ru',
    'inbox.ru',
    'bk.ru',
    'list.ru',
    'ok.ru',
    'sberbank.ru',
    'sber.ru',
    'sberpay.ru',
    'tbank.ru',
    'tinkoff.ru',
    'alfabank.ru',
    'vtb.ru',
    'raiffeisen.ru',
    'gosuslugi.ru',
    'mos.ru',
    'nalog.ru',
    'pfr.gov.ru',
    'wildberries.ru',
    'wb.ru',
    'ozon.ru',
    'rustore.ru',
  ];

  static const _privateIpRanges = [
    '0.0.0.0/8',
    '127.0.0.0/8',
    '10.0.0.0/8',
    '172.16.0.0/12',
    '192.168.0.0/16',
    '100.64.0.0/10',
    '169.254.0.0/16',
    '240.0.0.0/4',
    'fc00::/7',
    'fe80::/10',
    '::1/128',
  ];

  static const _yandexIpRanges = [
    '5.45.192.0/18',
    '5.255.192.0/18',
    '37.9.64.0/18',
    '37.140.128.0/18',
    '77.88.0.0/18',
    '84.201.128.0/18',
    '87.250.224.0/19',
    '93.158.128.0/18',
    '95.108.128.0/17',
    '141.8.128.0/18',
    '178.154.128.0/18',
    '213.180.192.0/18',
    '2a02:6b8::/32',
  ];
}
