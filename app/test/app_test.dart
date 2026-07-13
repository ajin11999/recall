import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/screens/login_screen.dart';

void main() {
  group('UI Tests', () {
    testWidgets('verify login screen rendering', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(onLogin: (url, token) async {}),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Server URL'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
    });
  });
}
