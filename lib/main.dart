import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'db/database_helper.dart';
import 'providers/theme_provider.dart';
import 'providers/app_lock_provider.dart';
import 'services/security/auth_service.dart';
import 'services/security/build_gate_service.dart';
import 'services/security/trial_gate_service.dart';
import 'services/security/migration_service.dart';
import 'services/security/screenshot_service.dart';
import 'utils/currency.dart';
import 'app.dart';

/// Top-level (isolate-safe) ffiInit callback.
/// sqflite_common_ffi spawns a background isolate for DB operations.
/// The open.overrideFor() call MUST run inside that isolate, so we
/// pass this function via createDatabaseFactoryFfi(ffiInit: _ffiInit).
void _ffiInit() {
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) debugPrint('[Startup] main()');

  DatabaseHelper.factory = createDatabaseFactoryFfi(ffiInit: _ffiInit);
  if (kDebugMode) debugPrint('[Startup] DatabaseHelper.factory set with SQLCipher ffiInit');

  sqfliteFfiInit();
  if (kDebugMode) debugPrint('[Startup] sqflite_common_ffi initialized');

  final authService = AuthService();
  final themeProvider = ThemeProvider();
  final appLockProvider = AppLockProvider(authService);
  final buildGateService = BuildGateService();
  final trialGateService = TrialGateService();

  // Critical: detect vault state before first frame
  await authService.init();
  await buildGateService.init();
  await trialGateService.init();

  // Apply screenshot preference (overrides default FLAG_SECURE)
  await ScreenshotService.apply();
  if (kDebugMode) debugPrint('[Startup] ScreenshotService.apply() complete');

  // Load saved currency preference
  await initCurrency();
  if (kDebugMode) debugPrint('[Startup] initCurrency() complete');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => buildGateService),
        ChangeNotifierProvider(create: (_) => trialGateService),
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => authService),
        ChangeNotifierProvider(create: (_) => appLockProvider),
      ],
      child: const CoinDropApp(),
    ),
  );
  if (kDebugMode) debugPrint('[Startup] runApp complete');

  // Defer non-critical init after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await MigrationService.run();
    if (kDebugMode) debugPrint('[Startup] MigrationService.run() complete (deferred)');

    await themeProvider.load();
    if (kDebugMode) debugPrint('[Startup] ThemeProvider.load() complete (deferred)');

    await appLockProvider.init();
    if (kDebugMode) debugPrint('[Startup] AppLockProvider.init() complete (deferred)');
  });
}
