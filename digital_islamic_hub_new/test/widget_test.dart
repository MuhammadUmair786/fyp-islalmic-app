import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_islamic_hub_new/widgets/app_logo.dart';

void main() {
  testWidgets('AppLogo renders a circular brand avatar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppLogo(radius: 24)),
      ),
    );
    expect(find.byType(CircleAvatar), findsOneWidget);
  });
}
