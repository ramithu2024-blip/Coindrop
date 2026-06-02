import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SECURITY: One-time migration to remove legacy SharedPreferences keys
/// that stored sensitive security state in plaintext XML in older versions.
/// This MUST run before AuthService.init() to prevent stale keys from
/// creating confusion or bypass opportunities.
class MigrationService {
  static const _migrationKey = 'security_migration_v2_complete';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> run() async {
    final prefs = await SharedPreferences.getInstance();

    final alreadyRan = prefs.getBool(_migrationKey) ?? false;
    if (alreadyRan) {
      if (kDebugMode) debugPrint('[Migration] Security migration v2 already complete, skipping');
      return;
    }

    if (kDebugMode) debugPrint('[Migration] Running security migration v2: removing legacy SharedPreferences keys');

    await prefs.remove('auth_pin_hash');
    await prefs.remove('auth_pin_enabled');
    await prefs.remove('auth_password_hash');
    await prefs.remove('auth_password_enabled');
    await prefs.remove('auth_biometric_enabled');
    await prefs.remove('encryption_enabled');
    await prefs.remove('auth_pin');
    await prefs.remove('app_pin');
    await prefs.remove('app_pin_enabled');
    await prefs.remove('require_unlock_on_startup');
    await prefs.remove('onboarding_completed');

    try {
      await _secureStorage.delete(key: 'auth_pin_hash');
      await _secureStorage.delete(key: 'auth_pin_enabled');
      await _secureStorage.delete(key: 'auth_biometric_enabled');
      await _secureStorage.delete(key: 'encryption_enabled');
    } catch (_) {}

    await prefs.setBool(_migrationKey, true);
    if (kDebugMode) debugPrint('[Migration] Security migration v2 complete');
  }
}
