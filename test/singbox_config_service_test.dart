import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:endvpn/core/services/singbox_config_service.dart';

void main() {
  group('SingboxConfigService', () {
    late SingboxConfigService service;

    setUp(() {
      service = SingboxConfigService();
    });

    test('maps server names to notification flags', () {
      expect(service.flagForServer('NL Нидерланды'), '🇳🇱');
      expect(service.flagForServer('DE Германия'), '🇩🇪');
      expect(service.flagForServer('Неизвестный сервер'), '🌐');
    });

    test('upgrades removed sing-box dns outbound and legacy inbound fields',
        () {
      final legacyConfig = jsonEncode({
        'dns': {
          'servers': [
            {'tag': 'remote', 'address': 'https://1.1.1.1/dns-query'},
          ],
        },
        'inbounds': [
          {
            'type': 'tun',
            'tag': 'tun-in',
            'sniff': true,
            'sniff_override_destination': false,
          }
        ],
        'outbounds': [
          {
            'type': 'vless',
            'tag': 'NL Netherlands',
            'server': 'example.com',
            'server_port': 443,
            'uuid': '00000000-0000-0000-0000-000000000000',
            'packet_encoding': 'xudp',
          },
          {'type': 'dns', 'tag': 'dns-out'},
          {
            'type': 'selector',
            'tag': 'proxy',
            'outbounds': ['NL Netherlands', 'dns-out'],
            'default': 'NL Netherlands',
          },
        ],
        'route': {
          'rules': [
            {'protocol': 'dns', 'outbound': 'dns-out'},
          ],
          'final': 'proxy',
        },
      });

      final upgraded = jsonDecode(service.upgradeConfig(legacyConfig))
          as Map<String, dynamic>;
      final outbounds = upgraded['outbounds'] as List;
      final inbounds = upgraded['inbounds'] as List;
      final route = upgraded['route'] as Map<String, dynamic>;
      final dns = upgraded['dns'] as Map<String, dynamic>;

      expect(outbounds.any((o) => o['tag'] == 'dns-out'), isFalse);
      expect(outbounds.first.containsKey('packet_encoding'), isFalse);
      expect(inbounds.first.containsKey('sniff'), isFalse);
      expect(inbounds.first.containsKey('sniff_override_destination'), isFalse);
      expect((route['rules'] as List).first['action'], 'hijack-dns');
      expect(route['default_domain_resolver'], 'local');
      expect(((dns['servers'] as List).first as Map)['type'], 'https');
    });

    test('removes direct detours from local dns servers', () {
      final upgraded = jsonDecode(service.upgradeConfig(jsonEncode({
        'dns': {
          'servers': [
            {
              'type': 'udp',
              'tag': 'local',
              'server': '223.5.5.5',
              'detour': 'direct',
            },
            {
              'type': 'udp',
              'tag': 'local-fallback',
              'server': '8.8.4.4',
              'detour': 'direct',
            },
            {
              'type': 'https',
              'tag': 'remote',
              'server': '1.1.1.1',
              'detour': 'NL Netherlands',
            },
          ],
        },
        'outbounds': [
          {'type': 'vless', 'tag': 'NL Netherlands'},
        ],
        'route': {},
      }))) as Map<String, dynamic>;

      final servers =
          (upgraded['dns'] as Map<String, dynamic>)['servers'] as List<dynamic>;

      expect((servers[0] as Map).containsKey('detour'), isFalse);
      expect((servers[1] as Map).containsKey('detour'), isFalse);
      expect((servers[2] as Map)['detour'], 'NL Netherlands');
    });

    test('parses vless subscriptions into clean server names and flags', () {
      final result = service.parseSubscription(
        'vless://00000000-0000-0000-0000-000000000000@example.com:443'
        '?security=reality&sni=example.com&fp=chrome&pbk=abc&sid=01#'
        '%F0%9F%87%B1%F0%9F%87%B9%20%D0%9B%D0%B8%D1%82%D0%B2%D0%B0',
      );

      expect(result.servers, hasLength(1));
      expect(result.servers.first.name, 'LT Литва');
      expect(result.servers.first.countryCode, 'LT');
      expect(result.configJson, isNotEmpty);
    });

    test('filters XHTTP nodes unsupported by bundled sing-box core', () {
      final result = service.parseSubscription(
        'vless://00000000-0000-0000-0000-000000000000@205.172.57.11:443'
        '?security=reality&sni=www.max.ru&fp=firefox&pbk=abc'
        '&type=xhttp&mode=auto&path=%2F&host=www.google.com#LT%20Lithuania\n'
        'vless://00000000-0000-0000-0000-000000000000@82.26.151.32:8443'
        '?security=reality&sni=www.apple.com&fp=chrome&pbk=abc&sid=01'
        '&type=grpc&serviceName=grpc#NL%20Netherlands',
      );

      expect(result.outbounds, hasLength(1));
      expect(result.servers, hasLength(2));
      final xhttpServer = result.servers.first;
      expect(xhttpServer.name, 'LT Lithuania');
      expect(xhttpServer.supported, isTrue);
      expect(xhttpServer.xrayConfig, isNotEmpty);
      final xray = jsonDecode(xhttpServer.xrayConfig!) as Map<String, dynamic>;
      expect(
          ((xray['outbounds'] as List).first as Map)['streamSettings']
              ['network'],
          'xhttp');
      expect(result.outbounds.first['tag'], 'NL Netherlands');
      expect(result.outbounds.first['transport']['type'], 'grpc');
    });

    test('keeps an XHTTP-only subscription for the Xray core', () {
      final result = service.parseSubscription(
        'vless://00000000-0000-0000-0000-000000000000@example.com:443'
        '?security=reality&sni=example.com&fp=chrome&pbk=abc&sid=01'
        '&type=xhttp&mode=auto&path=%2F#LV%20Latvia',
        target: SingboxConfigTarget.native,
      );

      expect(result.outbounds, isEmpty);
      expect(result.servers, hasLength(1));
      expect(result.servers.first.xrayConfig, isNotEmpty);
      expect(result.configJson, isNotEmpty);
    });

    test('keeps HTTP Upgrade nodes supported by bundled sing-box core', () {
      final result = service.parseSubscription(
        'vless://00000000-0000-0000-0000-000000000000@example.com:443'
        '?security=tls&sni=example.com&type=httpupgrade&path=%2Fvpn'
        '&host=edge.example.com#DE%20Germany',
      );

      expect(result.outbounds, hasLength(1));
      expect(result.outbounds.first['transport']['type'], 'httpupgrade');
      expect(result.outbounds.first['transport']['path'], '/vpn');
    });

    test('builds desktop config for sing-box 1.13 route actions', () {
      final config = jsonDecode(service.buildConfig([
        {
          'type': 'vless',
          'tag': 'NL Netherlands',
          'server': 'example.com',
          'server_port': 443,
          'uuid': '00000000-0000-0000-0000-000000000000',
        }
      ], 'NL Netherlands')) as Map<String, dynamic>;

      final dns = config['dns'] as Map<String, dynamic>;
      final route = config['route'] as Map<String, dynamic>;
      final dnsRule = (route['rules'] as List).first as Map;

      expect(((dns['servers'] as List).first as Map)['type'], 'udp');
      expect(dnsRule['protocol'], 'dns');
      expect(dnsRule['action'], 'hijack-dns');
      expect(dnsRule.containsKey('outbound'), isFalse);
    });

    test('builds native config compatible with bundled mobile libbox', () {
      final config = jsonDecode(service.buildConfig([
        {
          'type': 'vless',
          'tag': 'NL Netherlands',
          'server': 'example.com',
          'server_port': 443,
          'uuid': '00000000-0000-0000-0000-000000000000',
        }
      ], 'NL Netherlands', target: SingboxConfigTarget.native))
          as Map<String, dynamic>;

      final dns = config['dns'] as Map<String, dynamic>;
      final inbounds = config['inbounds'] as List;
      final route = config['route'] as Map<String, dynamic>;

      expect(((dns['servers'] as List).first as Map)['tag'], 'proxy-dns');
      expect(
          ((dns['servers'] as List).first as Map).containsKey('type'), isFalse);
      expect((inbounds.first as Map)['inet4_address'], '172.19.0.1/30');
      expect((inbounds.first as Map)['strict_route'], isTrue);
      expect(dns['final'], 'local-dns');
      expect(((dns['servers'] as List)[1] as Map)['address'], 'udp://1.1.1.1');
      expect(
        (route['rules'] as List).any((rule) =>
            rule is Map &&
            rule['protocol'] == 'dns' &&
            rule['outbound'] == 'dns-out'),
        isTrue,
      );
      expect(route.containsKey('default_domain_resolver'), isFalse);
    });

    test('rebuilds cached desktop config into native config without dns-out',
        () {
      final desktop = service.buildConfig([
        {
          'type': 'vless',
          'tag': 'NL Netherlands',
          'server': 'example.com',
          'server_port': 443,
          'uuid': '00000000-0000-0000-0000-000000000000',
        }
      ], 'NL Netherlands');

      final native = jsonDecode(service.rebuildConfig(
        desktop,
        'NL Netherlands',
        target: SingboxConfigTarget.native,
      )) as Map<String, dynamic>;

      final outbounds = native['outbounds'] as List;
      final dns = native['dns'] as Map<String, dynamic>;

      expect(outbounds.any((outbound) => outbound['tag'] == 'dns-out'), isTrue);
      expect(
          ((dns['servers'] as List).first as Map)['address'], 'tls://8.8.8.8');
    });

    group('xray bridge config', () {
      String xrayConfigFor(String address) => jsonEncode({
            'outbounds': [
              {
                'tag': 'proxy',
                'protocol': 'vless',
                'settings': {
                  'vnext': [
                    {
                      'address': address,
                      'port': 443,
                      'users': [
                        {'id': '00000000-0000-0000-0000-000000000000'}
                      ],
                    }
                  ],
                },
              },
            ],
          });

      test('excludes xray.exe process traffic from the tunnel', () {
        final bridge =
            jsonDecode(service.buildXrayBridgeConfig(xrayConfigFor('1.2.3.4')))
                as Map<String, dynamic>;
        final rules =
            (bridge['route'] as Map<String, dynamic>)['rules'] as List;

        expect(
          (rules.first as Map)['process_name'],
          'xray.exe',
          reason: 'the process rule must come first to break the routing loop',
        );
        expect((rules.first as Map)['outbound'], 'direct');
      });

      test('routes the VPS address direct as a fallback', () {
        final bridge =
            jsonDecode(service.buildXrayBridgeConfig(xrayConfigFor('1.2.3.4')))
                as Map<String, dynamic>;
        final rules =
            (bridge['route'] as Map<String, dynamic>)['rules'] as List;

        expect(
          rules.any((rule) =>
              rule is Map &&
              rule['outbound'] == 'direct' &&
              (rule['ip_cidr'] as List?)?.contains('1.2.3.4/32') == true),
          isTrue,
        );
      });

      test('uses a domain rule when the VPS address is a hostname', () {
        final bridge = jsonDecode(
                service.buildXrayBridgeConfig(xrayConfigFor('vpn.example.com')))
            as Map<String, dynamic>;
        final rules =
            (bridge['route'] as Map<String, dynamic>)['rules'] as List;

        expect(
          rules.any((rule) =>
              rule is Map &&
              rule['outbound'] == 'direct' &&
              (rule['domain'] as List?)?.contains('vpn.example.com') == true),
          isTrue,
        );
      });

      test('has a direct dns server to avoid bootstrap deadlock', () {
        final bridge =
            jsonDecode(service.buildXrayBridgeConfig(xrayConfigFor('1.2.3.4')))
                as Map<String, dynamic>;
        final dns = bridge['dns'] as Map<String, dynamic>;
        final servers = dns['servers'] as List;
        final route = bridge['route'] as Map<String, dynamic>;

        expect(
          servers.any((server) =>
              server is Map &&
              server['tag'] == 'direct-dns' &&
              !server.containsKey('detour')),
          isTrue,
        );
        expect(route['default_domain_resolver'], 'direct-dns');
        expect(route['final'], 'proxy');
        expect(route['auto_detect_interface'], isTrue);
      });

      test('builds the xray socks config with a local inbound', () {
        final config =
            jsonDecode(service.buildXraySocksConfig(xrayConfigFor('1.2.3.4')))
                as Map<String, dynamic>;
        final inbound = (config['inbounds'] as List).first as Map;

        expect(inbound['protocol'], 'socks');
        expect(inbound['listen'], '127.0.0.1');
        expect(inbound['port'], 17890);
      });
    });
  });
}
