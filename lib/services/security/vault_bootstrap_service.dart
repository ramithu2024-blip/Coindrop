import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VaultBootstrapService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<bool> isFirstRun() async {
    try {
      final hash = await _secureStorage.read(key: 'vault_hash');
      return hash == null || hash.isEmpty;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> vaultExists() async {
    return !(await isFirstRun());
  }
}
