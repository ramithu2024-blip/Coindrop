import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';
import '../secure/crypto_service.dart';

class VaultService {
  final CryptoService _crypto = CryptoService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String> createEncryptedVault(String pin, DatabaseHelper dbHelper) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN must be at least 4 characters');
    }

    final salt = _crypto.generateSalt();
    final derivedKey = _crypto.deriveKey(pin, salt);
    final vaultHash = _crypto.buildVaultHash(salt, derivedKey);
    final keyHex = _crypto.keyToHex(derivedKey);

    await dbHelper.open(keyHex);
    await _secureStorage.write(key: 'vault_hash', value: vaultHash);

    return keyHex;
  }

  Future<void> destroyVault() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      for (final name in ['coindrop.db', 'coindrop.db-wal', 'coindrop.db-shm']) {
        final file = File(p.join(dir.path, name));
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
