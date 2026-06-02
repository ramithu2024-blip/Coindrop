import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

NumberFormat _cachedFormat = NumberFormat.currency(
  locale: 'en_AU',
  symbol: '\$',
  decimalDigits: 2,
);

Future<void> initCurrency() async {
  final prefs = await SharedPreferences.getInstance();
  final locale = prefs.getString('currency_locale') ?? 'en_AU';
  final symbol = prefs.getString('currency_symbol') ?? '\$';
  _cachedFormat = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 2);
}

Future<void> setCurrency(String locale, String symbol) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('currency_locale', locale);
  await prefs.setString('currency_symbol', symbol);
  _cachedFormat = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 2);
}

String formatCurrency(double amount) => _cachedFormat.format(amount);

String formatCurrencyCompact(double amount) {
  if (amount >= 1000) {
    final suffix = amount >= 1000000 ? 'M' : 'k';
    final divisor = amount >= 1000000 ? 1000000.0 : 1000.0;
    return '\$${(amount / divisor).toStringAsFixed(1)}$suffix';
  }
  return formatCurrency(amount);
}
