class VpnServer {
  final String name;
  final String tag;
  final String countryCode;
  final bool supported;
  final String? xrayConfig;

  const VpnServer({
    required this.name,
    required this.tag,
    required this.countryCode,
    this.supported = true,
    this.xrayConfig,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'tag': tag,
        'country': countryCode,
        'supported': supported,
        if (xrayConfig != null) 'xrayConfig': xrayConfig,
      };

  factory VpnServer.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final tag = json['tag']?.toString() ?? name;
    return VpnServer(
      name: name,
      tag: tag,
      countryCode: json['country']?.toString() ?? 'WORLD',
      supported: json['supported'] != false,
      xrayConfig: json['xrayConfig']?.toString(),
    );
  }
}
