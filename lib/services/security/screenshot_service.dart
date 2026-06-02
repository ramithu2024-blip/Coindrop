import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScreenshotService {
  static const _channel = MethodChannel('com.coindrop.coindrop/security');
  static const _prefsKey = 'block_screenshots';

  static Future<bool> isBlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? true;
  }

  static Future<void> setBlocked(bool blocked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, blocked);
    await _channel.invokeMethod('setSecureMode', {'secure': blocked});
  }

  static Future<void> apply() async {
    final blocked = await isBlocked();
    await _channel.invokeMethod('setSecureMode', {'secure': blocked});
  }
}
