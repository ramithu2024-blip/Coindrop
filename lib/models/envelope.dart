import '../utils/constants.dart';

class Envelope {
  final int? id;
  final String name;
  final double initialAmount;
  final String createdAt;
  final int color;
  final String icon;

  Envelope({
    this.id,
    required this.name,
    required this.initialAmount,
    required this.createdAt,
    this.color = EnvelopeColors.defaultColor,
    this.icon = 'savings',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'initial_amount': initialAmount,
      'created_at': createdAt,
      'color': color,
      'icon': icon,
    };
  }

  factory Envelope.fromMap(Map<String, dynamic> map) {
    return Envelope(
      id: map['id'] as int?,
      name: map['name'] as String,
      initialAmount: (map['initial_amount'] as num).toDouble(),
      createdAt: map['created_at'] as String,
      color: map['color'] as int? ?? EnvelopeColors.defaultColor,
      icon: map['icon'] as String? ?? 'savings',
    );
  }

  Envelope copyWith({
    int? id,
    String? name,
    double? initialAmount,
    String? createdAt,
    int? color,
    String? icon,
  }) {
    return Envelope(
      id: id ?? this.id,
      name: name ?? this.name,
      initialAmount: initialAmount ?? this.initialAmount,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }
}
