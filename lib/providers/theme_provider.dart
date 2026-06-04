import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeOption {
  dark,
  light,
  system,
  timeBased;

  String get label {
    switch (this) {
      case ThemeModeOption.dark:
        return 'Dark';
      case ThemeModeOption.light:
        return 'Light';
      case ThemeModeOption.system:
        return 'System';
      case ThemeModeOption.timeBased:
        return 'Time Based';
    }
  }

  String get storageValue => name;

  static ThemeModeOption fromStorage(String value) {
    return ThemeModeOption.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ThemeModeOption.system,
    );
  }
}

class AccentColorOption {
  final String name;
  final Color color;
  final int value;

  const AccentColorOption({
    required this.name,
    required this.color,
    required this.value,
  });

  static const List<AccentColorOption> all = [
    AccentColorOption(name: 'Teal', color: Color(0xFF00BCD4), value: 0xFF00BCD4),
    AccentColorOption(name: 'Green', color: Color(0xFF4CAF50), value: 0xFF4CAF50),
    AccentColorOption(name: 'Blue', color: Color(0xFF2196F3), value: 0xFF2196F3),
    AccentColorOption(name: 'Purple', color: Color(0xFF9C27B0), value: 0xFF9C27B0),
    AccentColorOption(name: 'Orange', color: Color(0xFFFF9800), value: 0xFFFF9800),
    AccentColorOption(name: 'Red', color: Color(0xFFF44336), value: 0xFFF44336),
    AccentColorOption(name: 'Pink', color: Color(0xFFE91E63), value: 0xFFE91E63),
    AccentColorOption(name: 'Slate', color: Color(0xFF607D8B), value: 0xFF607D8B),
    AccentColorOption(name: 'Brown', color: Color(0xFF795548), value: 0xFF795548),
    AccentColorOption(name: 'Indigo', color: Color(0xFF3F51B5), value: 0xFF3F51B5),
  ];

  static AccentColorOption fromValue(int value) {
    return all.firstWhere(
      (a) => a.value == value,
      orElse: () {
        return AccentColorOption(
          name: 'Custom',
          color: Color(value),
          value: value,
        );
      },
    );
  }

  bool get isCustom => !all.any((a) => a.value == value);
}

class ThemeProvider extends ChangeNotifier {
  ThemeModeOption _themeModeOption = ThemeModeOption.system;
  int _accentColorValue = 0xFF4CAF50;
  bool _cashIconAccent = true;
  bool _useCustomEnvelopeColors = true;

  ThemeModeOption get themeModeOption => _themeModeOption;
  int get accentColorValue => _accentColorValue;
  Color get accentColor => Color(_accentColorValue);
  AccentColorOption get accentOption =>
      AccentColorOption.fromValue(_accentColorValue);
  bool get cashIconAccent => _cashIconAccent;
  bool get useCustomEnvelopeColors => _useCustomEnvelopeColors;

  ThemeMode get themeMode {
    switch (_themeModeOption) {
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.system:
        return ThemeMode.system;
      case ThemeModeOption.timeBased:
        final hour = DateTime.now().hour;
        return (hour >= 6 && hour < 19) ? ThemeMode.light : ThemeMode.dark;
    }
  }

  bool get isDarkMode {
    final mode = themeMode;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _themeModeOption = ThemeModeOption.fromStorage(
          prefs.getString('theme_mode') ?? 'system');
      _accentColorValue =
          prefs.getInt('accent_color') ?? 0xFF4CAF50;
      _cashIconAccent = prefs.getBool('cash_icon_accent') ?? true;
      _useCustomEnvelopeColors = prefs.getBool('use_custom_env_colors') ?? true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[Startup] ThemeProvider.load() error: $e');
    }
  }

  Future<void> setThemeMode(ThemeModeOption option) async {
    _themeModeOption = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', option.storageValue);
    notifyListeners();
  }

  Future<void> setCashIconAccent(bool v) async {
    _cashIconAccent = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cash_icon_accent', v);
    notifyListeners();
  }

  Future<void> setUseCustomEnvelopeColors(bool v) async {
    _useCustomEnvelopeColors = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_custom_env_colors', v);
    notifyListeners();
  }

  Future<void> setAccentColor(int value) async {
    _accentColorValue = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', value);
    notifyListeners();
  }

  bool isPresetColor(int value) {
    return AccentColorOption.all.any((a) => a.value == value);
  }
}
