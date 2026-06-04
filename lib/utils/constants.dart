import 'package:flutter/material.dart';

class EnvelopeIcons {
  static const Map<String, IconData> all = {
    'shopping_cart': Icons.shopping_cart,
    'local_gas_station': Icons.local_gas_station,
    'home': Icons.home,
    'directions_car': Icons.directions_car,
    'restaurant': Icons.restaurant,
    'flight': Icons.flight,
    'school': Icons.school,
    'medical_services': Icons.medical_services,
    'sports_esports': Icons.sports_esports,
    'pets': Icons.pets,
    'fitness_center': Icons.fitness_center,
    'local_mall': Icons.local_mall,
    'music_note': Icons.music_note,
    'movie': Icons.movie,
    'book': Icons.book,
    'work': Icons.work,
    'savings': Icons.savings,
    'credit_card': Icons.credit_card,
    'account_balance': Icons.account_balance,
    'payments': Icons.payments,
    'coffee': Icons.coffee,
    'train': Icons.train,
    'phone_android': Icons.phone_android,
    'checkroom': Icons.checkroom,
    'health_and_safety': Icons.health_and_safety,
    'receipt_long': Icons.receipt_long,
    'attach_money': Icons.attach_money,
    'security': Icons.security,
    'wallet': Icons.account_balance_wallet,
    'commute': Icons.commute,
    'shield': Icons.shield,
    'water_drop': Icons.water_drop,
    'local_laundry_service': Icons.local_laundry_service,
    'cleaning_services': Icons.cleaning_services,
    'handyman': Icons.handyman,
    'card_giftcard': Icons.card_giftcard,
  };

  static IconData getIcon(String? name) {
    if (name == null || !all.containsKey(name)) return Icons.account_balance_wallet;
    return all[name]!;
  }

  static String getName(IconData icon) {
    return all.entries.firstWhere((e) => e.value == icon).key;
  }
}

class EnvelopeColors {
  static const List<int> all = [
    0xFF00BCD4, // cyan
    0xFF4CAF50, // green
    0xFFFF5722, // deep orange
    0xFF9C27B0, // purple
    0xFFFF9800, // orange
    0xFF2196F3, // blue
    0xFFE91E63, // pink
    0xFF009688, // teal
    0xFFFFEB3B, // yellow
    0xFF673AB7, // deep purple
    0xFFCDDC39, // lime
    0xFF795548, // brown
    0xFF607D8B, // blue grey
    0xFFF44336, // red
    0xFF3F51B5, // indigo
  ];

  static const int defaultColor = 0xFF00BCD4;
}
