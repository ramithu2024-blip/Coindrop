import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppLockState {
  active,
  expiredLocked,
  unlocked,
}

class BuildGateService extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage;

  BuildGateService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _unlockKey = 'build_unlock';
  static const _unlockCode = 'OPENCOINDROP2026';

  AppLockState _state = AppLockState.active;
  bool _initialized = false;

  AppLockState get state => _state;
  bool get initialized => _initialized;

  static bool _isExpired() {
    final expiry = DateTime(2026, 12, 31);
    return DateTime.now().isAfter(expiry);
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final unlocked = await _secureStorage.read(key: _unlockKey);
    if (unlocked == 'true') {
      _state = AppLockState.unlocked;
      notifyListeners();
      return;
    }

    if (_isExpired()) {
      _state = AppLockState.expiredLocked;
      notifyListeners();
      return;
    }

    _state = AppLockState.active;
    notifyListeners();
  }

  Future<bool> attemptUnlock(String code) async {
    if (code != _unlockCode) return false;
    await _secureStorage.write(key: _unlockKey, value: 'true');
    _state = AppLockState.unlocked;
    notifyListeners();
    return true;
  }
}
