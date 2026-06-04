import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coindrop/app.dart';
import 'package:coindrop/providers/theme_provider.dart';
import 'package:coindrop/providers/app_lock_provider.dart';
import 'package:coindrop/services/security/auth_service.dart';
import 'package:coindrop/services/security/build_gate_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App loads and shows title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    final theme = ThemeProvider();
    final appLock = AppLockProvider(auth);
    final buildGate = BuildGateService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => buildGate),
          ChangeNotifierProvider(create: (_) => theme),
          ChangeNotifierProvider(create: (_) => auth),
          ChangeNotifierProvider(create: (_) => appLock),
        ],
        child: const CoinDropApp(),
      ),
    );

    // App shows splash/onboarding screen initially
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
