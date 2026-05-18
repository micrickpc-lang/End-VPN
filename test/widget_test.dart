import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endvpn/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(EndVpnApp(
      accentColor: const Color(0xFF00AAFF),
      tosAccepted: true, // ← добавь это
    ));
    expect(find.text('END'), findsAny);
  });
}