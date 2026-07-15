import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endvpn/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const EndVpnApp(
      accentColor: Color(0xFF7CC7D8),
      tosAccepted: false,
    ));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
