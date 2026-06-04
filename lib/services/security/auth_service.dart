import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';
import '../../models/recurring_payday.dart';
import '../../models/payday.dart';
import '../secure/crypto_service.dart';
import 'vault_service.dart';

/// Manages vault authentication, PIN verification, biometric unlock,
/// and brute-force protection.  All sensitive state lives in
/// FlutterSecureStorage — NOT SharedPreferences.
class AuthService extends ChangeNotifier {
  final CryptoService _crypto = CryptoService();
  final DatabaseHelper dbHelper;
  final VaultService _vaultService = VaultService();
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;
  bool _encryptionEnabled = true;

  AuthService({
    DatabaseHelper? dbHelper,
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  })  : dbHelper = dbHelper ?? DatabaseHelper(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  bool _initialized = false;
  bool _isAuthenticated = false;
  bool _hasVault = false;
  String? _cachedDbKeyB64;
  String? _vaultHash;

  bool _biometricAvailable = false;
  bool _biometricChecked = false;
  bool _vaultWiped = false;
  bool _biometricEnrolled = false;
  List<BiometricType> _availableBiometrics = [];
  String? _cachedAppDirPath;

  bool get biometricEnrolled => _biometricEnrolled;
  bool get biometricKeyAvailable => _cachedDbKeyB64 != null;
  bool get encryptionEnabled => _encryptionEnabled;

  void setEncryptionEnabled(bool v) {
    _encryptionEnabled = v;
    if (!v) {
      _cachedDbKeyB64 = null;
    }
    notifyListeners();
  }

  /// Derives the encryption key hex from the PIN using the stored vault hash.
  Future<String> deriveKeyHexFromPin(String pin) async {
    if (_vaultHash == null) throw StateError('No vault hash');
    final (salt, _) = _crypto.parseVaultHash(_vaultHash!);
    final key = _crypto.deriveKey(pin, salt);
    return _crypto.keyToHex(key);
  }

  /// FSS keys for biometric-persisted DB key (survives reboot).
  static const _biometricDbKey = 'biometric_db_key';
  static const _biometricEnrolledKey = 'biometric_enrolled';

  /// SharedPreferences key for user biometric opt-in (not security-critical).
  static const _biometricUserEnabledKey = 'biometric_user_enabled';

  Future<bool> getBiometricUserEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricUserEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setBiometricUserEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricUserEnabledKey, v);
    notifyListeners();
  }

  int _failedAttempts = 0;
  int _lockoutUntilEpoch = 0;

  bool get vaultWiped => _vaultWiped;
  bool get initialized => _initialized;
  bool get isAuthenticated => _isAuthenticated;
  bool get hasVault => _hasVault;
  bool get biometricAvailable => _biometricAvailable;
  bool get biometricChecked => _biometricChecked;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  int get failedAttempts => _failedAttempts;
  int get lockoutUntilEpoch => _lockoutUntilEpoch;

  bool get isLockedOut {
    if (_lockoutUntilEpoch == 0) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now < _lockoutUntilEpoch;
  }

  int get lockoutRemainingSeconds {
    if (!isLockedOut) return 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (_lockoutUntilEpoch - now).clamp(0, 999999);
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _vaultHash = await _secureStorage.read(key: 'vault_hash');
      _hasVault = _vaultHash != null && _vaultHash!.isNotEmpty;
    } catch (_) {
      _hasVault = false;
    }

    // If no vault_hash exists, delete any orphaned DB files from previous
    // installs.  Without an FSS vault_hash there is no valid vault, and a
    // stale coindrop.db would cause vault creation to fail (wrong key).
    if (!_hasVault) {
      await _cleanupOrphanedDbFiles();
    }

    // Check if a biometric-enrolled key exists (survives reboot).
    try {
      final enrolled = await _secureStorage.read(key: _biometricEnrolledKey);
      _biometricEnrolled = enrolled == 'true';
    } catch (_) {
      _biometricEnrolled = false;
    }

    _vaultWiped = false;
    await _loadBruteForceState();
    await _checkBiometrics();
    notifyListeners();
  }

  /// Deletes any database files that are not associated with a valid vault.
  /// Called during init() when no vault_hash is found in secure storage.
  Future<String> _appDirPath() async {
    if (_cachedAppDirPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _cachedAppDirPath = dir.path;
    }
    return _cachedAppDirPath!;
  }

  Future<void> _cleanupOrphanedDbFiles() async {
    try {
      final dirPath = await _appDirPath();
      for (final name in ['coindrop.db', 'coindrop.db-wal', 'coindrop.db-shm']) {
        final file = File(p.join(dirPath, name));
        if (await file.exists()) {
          if (kDebugMode) debugPrint('[Auth] Cleaning orphaned DB file: $name');
          await file.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] _cleanupOrphanedDbFiles error: $e');
    }
  }

  /// Loads brute-force counters from FlutterSecureStorage (not SharedPreferences).
  Future<void> _loadBruteForceState() async {
    try {
      final attempts = await _secureStorage.read(key: 'vault_failed_attempts');
      _failedAttempts = int.tryParse(attempts ?? '0') ?? 0;
      final lockout = await _secureStorage.read(key: 'vault_lockout_until');
      _lockoutUntilEpoch = int.tryParse(lockout ?? '0') ?? 0;
    } catch (_) {
      _failedAttempts = 0;
      _lockoutUntilEpoch = 0;
    }
  }

  /// Persists brute-force counters to FlutterSecureStorage.
  Future<void> _saveBruteForceState() async {
    try {
      if (_failedAttempts > 0) {
        await _secureStorage.write(key: 'vault_failed_attempts', value: '$_failedAttempts');
      } else {
        await _secureStorage.delete(key: 'vault_failed_attempts');
      }
      if (_lockoutUntilEpoch > 0) {
        await _secureStorage.write(key: 'vault_lockout_until', value: '$_lockoutUntilEpoch');
      } else {
        await _secureStorage.delete(key: 'vault_lockout_until');
      }
    } catch (_) {}
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      _biometricAvailable = canCheck || deviceSupported;
      if (_biometricAvailable) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] _checkBiometrics error: $e');
      _biometricAvailable = false;
      _availableBiometrics = [];
    }
    _biometricChecked = true;
    notifyListeners();
  }

  /// Stores the current DB key in FSS for biometric unlock across reboots.
  /// Waits for [_cachedDbKeyB64] to be non-null.
  /// No-op when encryption is disabled (no key to store).
  Future<void> storeBiometricKey() async {
    if (_encryptionEnabled) {
      if (_cachedDbKeyB64 == null) return;
      await _secureStorage.write(key: _biometricDbKey, value: _cachedDbKeyB64);
    }
    await _secureStorage.write(key: _biometricEnrolledKey, value: 'true');
    _biometricEnrolled = true;
    notifyListeners();
  }

  /// Removes the stored biometric DB key and enrollment flag.
  Future<void> deleteBiometricKey() async {
    await _secureStorage.delete(key: _biometricDbKey);
    await _secureStorage.delete(key: _biometricEnrolledKey);
    _biometricEnrolled = false;
    notifyListeners();
  }

  /// Sets up a new vault with [pin].  Creates the encrypted DB, derives the
  /// encryption key via PBKDF2-SHA256 (100k iterations), and stores the
  /// verification hash in FlutterSecureStorage.
  Future<bool> setupPin(String pin) async {
    if (pin.length < 4) return false;

    try {
      if (kDebugMode) debugPrint('[Auth] setupPin: step 1/6 generate salt');
      final salt = _crypto.generateSalt();

      if (kDebugMode) debugPrint('[Auth] setupPin: step 2/6 derive key (PBKDF2 100k)');
      final derivedKey = _crypto.deriveKey(pin, salt);

      if (kDebugMode) debugPrint('[Auth] setupPin: step 3/6 build vault hash');
      final vaultHash = _crypto.buildVaultHash(salt, derivedKey);

      if (kDebugMode) debugPrint('[Auth] setupPin: step 4/6 open encrypted DB');
      final keyHex = _crypto.keyToHex(derivedKey);
      await dbHelper.open(keyHex);

      if (kDebugMode) debugPrint('[Auth] setupPin: step 5/6 persist vault hash');
      await _secureStorage.write(key: 'vault_hash', value: vaultHash);

      _vaultHash = vaultHash;
      _hasVault = true;
      _isAuthenticated = true;
      _cachedDbKeyB64 = keyHex;

      if (kDebugMode) debugPrint('[Auth] setupPin: step 6/6 reset brute-force state');
      await _resetBruteForceState();

      notifyListeners();
      if (kDebugMode) debugPrint('[Auth] setupPin: vault created successfully');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] setupPin FAILED: $e');
      if (kDebugMode) debugPrint('[Auth] setupPin stack: ${StackTrace.current}');
      await dbHelper.close();
      return false;
    }
  }

  /// Verifies [pin] against the stored vault hash.
  /// On failure increments brute-force counter and applies lockout.
  /// Lockout only blocks SUCCESSFUL unlocks; failed attempts always
  /// accumulate so the 10th attempt can trigger a vault wipe.
  Future<bool> verifyPin(String pin) async {
    if (!_hasVault || _vaultHash == null) return false;

    try {
      final (salt, storedVerHash) = _crypto.parseVaultHash(_vaultHash!);
      if (salt.isEmpty || storedVerHash == null) return false;

      final derivedKey = _crypto.deriveKey(pin, salt);

      if (!_crypto.verifyDerivedKey(derivedKey, storedVerHash)) {
        await _handleFailedAttempt();
        return false;
      }

      // Correct PIN — unlock and reset brute-force state.

      if (_encryptionEnabled) {
        final keyHex = _crypto.keyToHex(derivedKey);
        await dbHelper.open(keyHex);
        _cachedDbKeyB64 = keyHex;
      } else {
        await dbHelper.openPlain();
        _cachedDbKeyB64 = null;
      }

      _isAuthenticated = true;
      await _resetBruteForceState();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] verifyPin error: $e');
      await dbHelper.close();
      _isAuthenticated = false;
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // PIN Brute-Force Protection
  // Policy: 5 failures -> 30s lockout, 6->60s, 7->120s, 8->300s, 9->600s,
  //          10 -> vault wipe
  // ---------------------------------------------------------------------------

  Future<void> _handleFailedAttempt() async {
    _failedAttempts++;
    if (_failedAttempts >= 10) {
      final wiped = await _tryWipeVault();
      if (wiped) {
        _vaultWiped = true;
        _hasVault = false;
        _isAuthenticated = false;
        _cachedDbKeyB64 = null;
        _vaultHash = null;
        _failedAttempts = 0;
        _lockoutUntilEpoch = 0;
        notifyListeners();
      } else {
        _lockoutUntilEpoch = _computeLockoutDuration();
        await _saveBruteForceState();
        notifyListeners();
      }
      return;
    }
    _lockoutUntilEpoch = _computeLockoutDuration();
    await _saveBruteForceState();
    notifyListeners();
  }

  int _computeLockoutDuration() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_failedAttempts < 5) return 0;
    final delays = [0, 0, 0, 0, 30, 60, 120, 300, 600];
    final index = (_failedAttempts - 1).clamp(0, delays.length - 1);
    return now + delays[index];
  }

  Future<void> _resetBruteForceState() async {
    _failedAttempts = 0;
    _lockoutUntilEpoch = 0;
    await _saveBruteForceState();
  }

  /// Tries to destroy the vault after 10 failed PIN attempts.
  /// Returns `true` only if ALL deletion steps succeeded.
  /// If any step fails, the vault is left intact and false is returned.
  Future<bool> _tryWipeVault() async {
    if (kDebugMode) debugPrint('[Auth] Attempting vault wipe after 10 failed PIN attempts');
    if (dbHelper.isOpen) {
      await dbHelper.close();
    }

    bool ok = true;

    // 1. Delete encrypted database files
    try {
      final dirPath = await _appDirPath();
      for (final name in ['coindrop.db', 'coindrop.db-wal', 'coindrop.db-shm']) {
        final file = File(p.join(dirPath, name));
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] DB file deletion failed: $e');
      ok = false;
    }

    // 2. Delete secure storage secrets (vault_hash, biometric keys, etc.)
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] Secure storage deletion failed: $e');
      ok = false;
    }

    // 3. Clear SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] SharedPreferences clear failed: $e');
      ok = false;
    }

    if (!ok) {
      if (kDebugMode) debugPrint('[Auth] Vault wipe FAILED — some deletions did not succeed');
    }

    return ok;
  }

  // ---------------------------------------------------------------------------
  // Lock / Unlock (including biometric unlock from persistent FSS key)
  // ---------------------------------------------------------------------------

  /// SECURITY: On lock, close the DB and clear the cached key.
  /// The persistent biometric key in FSS survives so biometric unlock
  /// works even after restart.
  Future<void> lock() async {
    await dbHelper.close();
    _cachedDbKeyB64 = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Attempts biometric unlock.  Uses local_auth to verify the user's
  /// identity, then reads the persisted DB key from FSS.  Works after
  /// reboot because the key is stored in FSS (encrypted at rest by
  /// Android Keystore).
  Future<bool> unlockWithBiometrics() async {
    if (!_biometricAvailable) return false;
    if (isLockedOut) return false;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock your financial vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (!authenticated) return false;

      if (_encryptionEnabled) {
        final storedKey = await _secureStorage.read(key: _biometricDbKey);
        if (storedKey == null || storedKey.isEmpty) return false;
        await dbHelper.open(storedKey);
        _cachedDbKeyB64 = storedKey;
      } else {
        await dbHelper.openPlain();
        _cachedDbKeyB64 = null;
      }

      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] unlockWithBiometrics error: $e');
      return false;
    }
  }

  Future<bool> canUnlockWithBiometrics() async {
    if (!_biometricAvailable) return false;
    if (!_biometricEnrolled) return false;
    if (isLockedOut) return false;
    return await getBiometricUserEnabled();
  }

  /// Checks SharedPreferences for pending onboarding payday setup data.
  /// If present, creates the recurring payday rule in the DB and removes the
  /// pending flag.  Called after vault creation in PinScreen.
  static const _pendingPaydayKey = 'onboarding_payday_setup';

  bool _importedPendingPayday = false;

  Future<void> importPendingOnboardingPayday() async {
    if (_importedPendingPayday) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingPaydayKey);
    if (raw == null || raw.isEmpty) { _importedPendingPayday = true; return; }
    if (!dbHelper.isOpen) return;
    await prefs.remove(_pendingPaydayKey);
    _importedPendingPayday = true;
    try {
      final data = raw.split('|');
      if (data.length < 2) return;
      final amount = double.tryParse(data[0]);
      if (amount == null || amount <= 0) return;
      final frequency = data[1];
      final weekday = frequency == 'weekly' ? int.tryParse(data[2]) : null;
      final monthDay = frequency == 'monthly' ? int.tryParse(data[2]) : null;
      final note = data.length > 3 ? data[3] : '';
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final rule = RecurringPayday(
        amount: amount,
        frequency: frequency,
        weekday: weekday,
        monthDay: monthDay,
        note: note,
        enabled: true,
        lastProcessedDate: todayStr,
      );
      await dbHelper.insertRecurringPayday(rule);
      if (kDebugMode) debugPrint('[Auth] Imported pending onboarding payday: $amount $frequency');
    } catch (_) {}
  }

  static const _startingBalanceKey = 'onboarding_starting_balance';

  bool _importedStartingBalance = false;

  Future<void> importStartingBalance() async {
    if (_importedStartingBalance) return;
    final prefs = await SharedPreferences.getInstance();
    final amount = prefs.getDouble(_startingBalanceKey);
    if (amount == null || amount <= 0) { _importedStartingBalance = true; return; }
    if (!dbHelper.isOpen) return;
    await prefs.remove(_startingBalanceKey);
    _importedStartingBalance = true;
    try {
      final payday = Payday(
        amount: amount,
        note: 'Starting Balance',
        date: DateTime.now().toIso8601String(),
      );
      await dbHelper.insertPayday(payday);
      if (kDebugMode) debugPrint('[Auth] Imported starting balance: $amount');
    } catch (_) {}
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PIN Change & Vault Destruction
  // ---------------------------------------------------------------------------

  Future<void> changePin(String oldPin, String newPin) async {
    final (salt, storedVerHash) = _crypto.parseVaultHash(_vaultHash!);
    if (salt.isEmpty || storedVerHash == null) {
      throw StateError('Vault not initialized');
    }
    final oldKey = _crypto.deriveKey(oldPin, salt);
    if (!_crypto.verifyDerivedKey(oldKey, storedVerHash)) {
      throw ArgumentError('Current PIN is incorrect');
    }
    final newSalt = _crypto.generateSalt();
    final newKey = _crypto.deriveKey(newPin, newSalt);
    final newVaultHash = _crypto.buildVaultHash(newSalt, newKey);
    await _secureStorage.write(key: 'vault_hash', value: newVaultHash);
    _vaultHash = newVaultHash;

    if (_encryptionEnabled) {
      final newKeyHex = _crypto.keyToHex(newKey);
      if (dbHelper.isOpen) {
        await dbHelper.close();
      }
      await dbHelper.open(newKeyHex);
      _cachedDbKeyB64 = newKeyHex;

      // Update the stored biometric key if enrolled.
      if (_biometricEnrolled) {
        await _secureStorage.write(key: _biometricDbKey, value: newKeyHex);
      }
    } else {
      _cachedDbKeyB64 = null;
    }
  }

  Future<void> destroyVault() async {
    if (dbHelper.isOpen) {
      await dbHelper.close();
    }
    await _vaultService.destroyVault();
    await deleteBiometricKey();
    _vaultWiped = false;
    _hasVault = false;
    _isAuthenticated = false;
    _cachedDbKeyB64 = null;
    _vaultHash = null;
    _failedAttempts = 0;
    _lockoutUntilEpoch = 0;
    notifyListeners();
  }

  Future<bool> resetWithPin(String pin) async {
    await destroyVault();
    return await setupPin(pin);
  }

  @override
  void dispose() {
    dbHelper.close();
    super.dispose();
  }
}
