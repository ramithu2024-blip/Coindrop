import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum TrialState {
  active,
  expired,
  unlocked,
}

class TrialGateService extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage;

  TrialGateService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _firstRunKey = 'trial_first_run';
  static const _unlockKey = 'trial_unlock';
  static const _unlockCode = 'Ram95ins';
  static const _trialDays = 7;

  TrialState _state = TrialState.active;
  bool _initialized = false;

  TrialState get state => _state;
  bool get initialized => _initialized;
  bool get isExpired => _state == TrialState.expired;
  bool get isUnlocked => _state == TrialState.unlocked;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final unlocked = await _secureStorage.read(key: _unlockKey);
    if (unlocked == 'true') {
      _state = TrialState.unlocked;
      notifyListeners();
      return;
    }

    final stored = await _secureStorage.read(key: _firstRunKey);
    if (stored == null) {
      await _secureStorage.write(
        key: _firstRunKey,
        value: DateTime.now().toIso8601String(),
      );
      _state = TrialState.active;
      notifyListeners();
      return;
    }

    final firstRun = DateTime.parse(stored);
    final deadline = firstRun.add(Duration(days: _trialDays));
    if (DateTime.now().isAfter(deadline)) {
      _state = TrialState.expired;
    } else {
      _state = TrialState.active;
    }
    notifyListeners();
  }

  Future<bool> attemptUnlock(String code) async {
    if (code != _unlockCode) return false;
    await _secureStorage.write(key: _unlockKey, value: 'true');
    _state = TrialState.unlocked;
    notifyListeners();
    return true;
  }
}
