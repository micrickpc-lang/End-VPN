class VpnSpeedService {
  const VpnSpeedService._();

  /// Native traffic events report bytes per second. Formatted values are a
  /// fallback for platforms that only expose a human-readable speed.
  static double toMbps(dynamic raw) {
    if (raw is num) return raw <= 0 ? 0 : raw * 8 / 1000000;
    if (raw is! String) return 0;

    final match = RegExp(
      r'^\s*([\d]+(?:[.,][\d]+)?)\s*([a-zA-Z/]+)?',
    ).firstMatch(raw);
    if (match == null) return 0;
    final value = double.tryParse((match.group(1) ?? '').replaceAll(',', '.'));
    if (value == null || value <= 0) return 0;
    switch ((match.group(2) ?? '').toLowerCase()) {
      case 'gb/s':
        return value * 8000;
      case 'mb/s':
        return value * 8;
      case 'kb/s':
        return value * 0.008;
      case 'b/s':
        return value * 0.000008;
      case 'gib/s':
        return value * 8589.934592;
      case 'mib/s':
        return value * 8.388608;
      case 'kib/s':
        return value * 0.008388608;
      case 'gbps':
        return value * 1000;
      case 'mbps':
        return value;
      case 'kbps':
        return value / 1000;
      default:
        return value * 8 / 1000000;
    }
  }
}
