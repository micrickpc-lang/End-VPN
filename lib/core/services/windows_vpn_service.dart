import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:endvpn/core/services/singbox_config_service.dart';

const bool kVpnCoreLogs = false;

enum WindowsVpnStatus { idle, starting, connected, error }

class WindowsVpnState {
  final WindowsVpnStatus status;
  final String? errorMessage;

  const WindowsVpnState(this.status, [this.errorMessage]);

  static const idle = WindowsVpnState(WindowsVpnStatus.idle);
  static const starting = WindowsVpnState(WindowsVpnStatus.starting);
  static const connected = WindowsVpnState(WindowsVpnStatus.connected);
}

class WindowsVpnService {
  static final WindowsVpnService _instance = WindowsVpnService._internal();
  factory WindowsVpnService() => _instance;
  WindowsVpnService._internal();

  final _configService = SingboxConfigService();
  final state = ValueNotifier<WindowsVpnState>(WindowsVpnState.idle);

  Process? _singBoxProcess;
  Process? _xrayProcess;
  int _generation = 0;

  bool get isRunning => _singBoxProcess != null;

  Future<void> startSingBox(String config) async {
    state.value = WindowsVpnState.starting;
    final generation = ++_generation;
    try {
      await _ensureNoConflictingVpn();
      await _startSingBoxProcess(config, generation);
      await _verifyTunnelOrThrow();
      state.value = WindowsVpnState.connected;
    } catch (e) {
      await stop();
      state.value = WindowsVpnState(WindowsVpnStatus.error, e.toString());
      rethrow;
    }
  }

  Future<void> startXrayBridge(String rawXrayConfig) async {
    state.value = WindowsVpnState.starting;
    final generation = ++_generation;
    try {
      await _ensureNoConflictingVpn();
      await _startXrayProcess(rawXrayConfig, generation);
      final bridgeConfig = _configService.buildXrayBridgeConfig(rawXrayConfig);
      await _startSingBoxProcess(bridgeConfig, generation);
      await _verifyTunnelOrThrow();
      state.value = WindowsVpnState.connected;
    } catch (e) {
      await stop();
      state.value = WindowsVpnState(WindowsVpnStatus.error, e.toString());
      rethrow;
    }
  }

  Future<void> stop() async {
    _generation++;
    final singBox = _singBoxProcess;
    _singBoxProcess = null;
    singBox?.kill(ProcessSignal.sigterm);
    final xray = _xrayProcess;
    _xrayProcess = null;
    xray?.kill(ProcessSignal.sigterm);
    if (state.value.status != WindowsVpnStatus.error) {
      state.value = WindowsVpnState.idle;
    }
  }

  Future<Directory> _appDir() async {
    final dir = Directory(
      '${Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}\\EndVPN',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _ensureTool(String name) async {
    final appDir = await _appDir();
    final binDir = Directory('${appDir.path}\\bin');
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    final bundled = File(
      '${File(Platform.resolvedExecutable).parent.path}\\data\\tools\\windows\\$name',
    );
    if (!await bundled.exists()) {
      throw Exception('Bundled Windows tool is missing: $name');
    }
    final exe = File('${binDir.path}\\$name');
    if (!await exe.exists() || await exe.length() != await bundled.length()) {
      await bundled.copy(exe.path);
    }
    return exe;
  }

  Future<Process> _launchCore({
    required File exe,
    required File configFile,
    required String label,
    required int generation,
    required Duration startupGrace,
  }) async {
    final errors = <String>[];
    final process = await Process.start(
      exe.path,
      ['run', '-c', configFile.path],
      workingDirectory: exe.parent.path,
      runInShell: false,
    );

    process.stdout.transform(utf8.decoder).listen((line) {
      if (kVpnCoreLogs) debugPrint('$label: $line');
    });
    process.stderr.transform(utf8.decoder).listen((line) {
      errors.add(line.trim());
      if (kVpnCoreLogs) debugPrint('$label error: $line');
    });

    await Future.delayed(startupGrace);
    final exitCode = await process.exitCode.timeout(
      const Duration(milliseconds: 1),
      onTimeout: () => -1,
    );
    if (exitCode != -1) {
      final detail = errors.where((e) => e.isNotEmpty).join('\n');
      throw Exception(
          detail.isEmpty ? '$label exited with code $exitCode' : detail);
    }

    process.exitCode.then((code) => _onCoreExit(label, code, generation));
    return process;
  }

  void _onCoreExit(String label, int code, int generation) {
    if (generation != _generation) return;
    _singBoxProcess?.kill(ProcessSignal.sigterm);
    _singBoxProcess = null;
    _xrayProcess?.kill(ProcessSignal.sigterm);
    _xrayProcess = null;
    state.value = WindowsVpnState(
      WindowsVpnStatus.error,
      'VPN core "$label" остановилось (код $code)',
    );
  }

  Future<void> _startSingBoxProcess(String config, int generation) async {
    final exe = await _ensureTool('sing-box.exe');
    final appDir = await _appDir();
    final configFile = File('${appDir.path}\\sing-box-config.json');
    await configFile.writeAsString(config, flush: true);

    _singBoxProcess?.kill(ProcessSignal.sigterm);
    _singBoxProcess = await _launchCore(
      exe: exe,
      configFile: configFile,
      label: 'sing-box',
      generation: generation,
      startupGrace: const Duration(milliseconds: 900),
    );
  }

  Future<void> _startXrayProcess(String rawXrayConfig, int generation) async {
    final exe = await _ensureTool('xray.exe');
    await _ensureTool('geoip.dat');
    await _ensureTool('geosite.dat');

    final appDir = await _appDir();
    final configFile = File('${appDir.path}\\xray-config.json');
    await configFile.writeAsString(
      _configService.buildXraySocksConfig(rawXrayConfig),
      flush: true,
    );

    _xrayProcess?.kill(ProcessSignal.sigterm);
    _xrayProcess = await _launchCore(
      exe: exe,
      configFile: configFile,
      label: 'xray',
      generation: generation,
      startupGrace: const Duration(milliseconds: 700),
    );
  }

  Future<void> _verifyTunnelOrThrow() async {
    if (!await _hasEndVpnAdapter()) {
      throw Exception(
        'Не удалось создать системный маршрут END VPN. '
        'Закройте другие VPN-приложения и повторите подключение.',
      );
    }
    if (await verifyTunnel()) return;
    throw Exception(
      'Подключено, но трафик не проходит через VPN. Попробуйте другой сервер.',
    );
  }

  Future<void> _ensureNoConflictingVpn() async {
    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r"Get-NetAdapter -IncludeHidden | Where-Object { $_.Status -eq 'Up' -and $_.Name -ne 'EndVPN' -and ($_.InterfaceDescription -match 'Wintun|WireGuard|TAP|sing-tun|Tunnel' -or $_.Name -match 'happ|tun|vpn|warp') } | Select-Object -ExpandProperty Name",
      ],
      runInShell: false,
    );
    final adapters = result.stdout
        .toString()
        .split(RegExp(r'[\r\n]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (adapters.isEmpty) return;
    throw Exception(
      'Обнаружен другой VPN (${adapters.join(', ')}). '
      'Отключите его перед запуском END VPN.',
    );
  }

  Future<bool> _hasEndVpnAdapter() async {
    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r"$adapter = Get-NetAdapter -IncludeHidden -Name 'EndVPN' -ErrorAction SilentlyContinue; if ($adapter -and $adapter.Status -eq 'Up') { 'UP' }",
      ],
      runInShell: false,
    );
    return result.stdout.toString().trim() == 'UP';
  }

  Future<bool> verifyTunnel() async {
    const urls = [
      'https://cp.cloudflare.com/generate_204',
      'https://www.gstatic.com/generate_204',
    ];
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 2));
      for (final url in urls) {
        if (await _probe(url)) return true;
      }
    }
    return false;
  }

  Future<bool> _probe(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      final response =
          await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
