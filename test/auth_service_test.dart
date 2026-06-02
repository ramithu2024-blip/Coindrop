import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coindrop/services/security/auth_service.dart';
import 'package:coindrop/db/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mock Secure Storage
// ---------------------------------------------------------------------------
class _MockSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _store = {};
  bool _failDeleteAll = false;

  void setFailDeleteAll(bool v) => _failDeleteAll = v;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store.remove(key);

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      Map.from(_store);

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_failDeleteAll) throw Exception('Simulated FSS deleteAll failure');
    _store.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store.containsKey(key);
}

// ---------------------------------------------------------------------------
// Mock DatabaseHelper — uses in-memory ffi (needs libsqlite3.so on PATH)
// ---------------------------------------------------------------------------
class _MockDbHelper extends DatabaseHelper {
  Database? _db;

  @override
  bool get isOpen => _db != null;

  @override
  Future<Database> open(String hexKey) async {
    _db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    return _db!;
  }

  @override
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider for test environment
  const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathChannel, (MethodCall call) async {
    if (call.method == 'getApplicationDocumentsDirectory') {
      return Directory.current.path;
    }
    return null;
  });

  // Mock local_auth (avoids MissingPluginException)
  const _authChannel = MethodChannel('plugins.flutter.io/local_auth');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_authChannel, (MethodCall call) async {
    return false;
  });

  sqfliteFfiInit();

  group('AuthService lockout/wipe state machine', () {
    late AuthService auth;
    late _MockSecureStorage secureStorage;
    late _MockDbHelper dbHelper;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      secureStorage = _MockSecureStorage();
      dbHelper = _MockDbHelper();

      auth = AuthService(
        dbHelper: dbHelper,
        secureStorage: secureStorage,
        localAuth: LocalAuthentication(),
      );
      await auth.init();

      final setupOk = await auth.setupPin('1234');
      expect(setupOk, isTrue);
    });

    tearDown(() async {
      if (dbHelper.isOpen) {
        await dbHelper.close();
      }
    });

    test('lockout only — 9 wrong attempts, vault intact, isLockedOut true, vaultWiped false', () async {
      for (int i = 0; i < 9; i++) {
        final ok = await auth.verifyPin('0000');
        expect(ok, isFalse);
      }

      expect(auth.isLockedOut, isTrue);
      expect(auth.vaultWiped, isFalse);
      expect(auth.hasVault, isTrue);

      final vaultHash = await secureStorage.read(key: 'vault_hash');
      expect(vaultHash, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('successful wipe — 10 wrong attempts, vault deleted, vaultWiped true, isLockedOut false', () async {
      for (int i = 0; i < 10; i++) {
        final ok = await auth.verifyPin('0000');
        expect(ok, isFalse);
      }

      expect(auth.vaultWiped, isTrue);
      expect(auth.hasVault, isFalse);
      expect(auth.isLockedOut, isFalse);

      final vaultHash = await secureStorage.read(key: 'vault_hash');
      expect(vaultHash, isNull);

      final biometricKey = await secureStorage.read(key: 'biometric_db_key');
      expect(biometricKey, isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('failed wipe — FSS deleteAll throws, vaultWiped false, lockout shown', () async {
      for (int i = 0; i < 9; i++) {
        final ok = await auth.verifyPin('0000');
        expect(ok, isFalse);
      }

      secureStorage.setFailDeleteAll(true);

      final ok = await auth.verifyPin('0000');
      expect(ok, isFalse);

      expect(auth.vaultWiped, isFalse);
      expect(auth.hasVault, isTrue);
      expect(auth.isLockedOut, isTrue);
      expect(auth.lockoutRemainingSeconds, greaterThan(0));

      final vaultHash = await secureStorage.read(key: 'vault_hash');
      expect(vaultHash, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('lockout resets after correct PIN entry', () async {
      for (int i = 0; i < 5; i++) {
        await auth.verifyPin('0000');
      }
      expect(auth.isLockedOut, isTrue);
      expect(auth.failedAttempts, 5);

      await auth.verifyPin('1234');
      expect(auth.isLockedOut, isFalse);
      expect(auth.failedAttempts, 0);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('states are mutually exclusive — never both lockout and wiped', () async {
      for (int i = 0; i < 5; i++) {
        await auth.verifyPin('0000');
      }
      expect(auth.isLockedOut, isTrue);
      expect(auth.vaultWiped, isFalse);

      await auth.verifyPin('1234');

      for (int i = 0; i < 10; i++) {
        await auth.verifyPin('0000');
      }
      expect(auth.vaultWiped, isTrue);
      expect(auth.isLockedOut, isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
