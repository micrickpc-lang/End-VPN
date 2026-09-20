import 'package:endvpn/core/services/vpn_speed_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses actual bytes per second without inventing traffic', () {
    expect(VpnSpeedService.toMbps(0), 0);
    expect(VpnSpeedService.toMbps(125000), 1);
    expect(VpnSpeedService.toMbps(-1), 0);
  });

  test('converts formatted native traffic speeds to Mbps', () {
    expect(VpnSpeedService.toMbps('0 B/s'), 0);
    expect(VpnSpeedService.toMbps('125 KB/s'), 1);
    expect(VpnSpeedService.toMbps('1.5 MB/s'), 12);
    expect(VpnSpeedService.toMbps('2 Mbps'), 2);
    expect(VpnSpeedService.toMbps('500 kbps'), 0.5);
    expect(VpnSpeedService.toMbps('unavailable'), 0);
  });
}
