import 'package:endvpn/core/services/remnawave_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('free plan is 15 GB and resets monthly in Remnawave', () {
    expect(
      RemnawaveService.freeTrafficLimitBytes,
      15 * 1024 * 1024 * 1024,
    );
    expect(RemnawaveService.freeTrafficLimitStrategy, 'MONTH');
  });
}
