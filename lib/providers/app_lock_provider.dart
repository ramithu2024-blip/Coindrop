import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/security/auth_service.dart';

/// Monitors app lifecycle and enforces auto-lock after a configurable
/// period of inactivity.  Reads the auto-lock duration from SharedPreferences
/// (set by the user in SecurityScreen) and converts minutes to seconds.
class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AuthService _auth;
  bool _initialized = false;
  DateTime? _lastActiveTime;
  int _autoLockSeconds = 300;

  AppLockProvider(this._auth);

  bool get isLocked => !_auth.isAuthenticated;
  bool get isUnlocked => _auth.isAuthenticated;
  bool get hasVault => _auth.hasVault;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    _autoLockSeconds = (prefs.getInt('auto_lock_minutes') ?? 5) * 60;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lastActiveTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_auth.isAuthenticated && _lastActiveTime != null) {
        final elapsed = DateTime.now().difference(_lastActiveTime!);
        if (elapsed.inSeconds >= _autoLockSeconds) {
          _auth.lock();
        }
      }
      _lastActiveTime = null;
    }
  }

  Future<void> lock() async {
    await _auth.lock();
    notifyListeners();
  }

  Future<bool> unlock() async {
    return _auth.isAuthenticated;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
