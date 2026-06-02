class RecurringPayday {
  final int? id;
  final double amount;
  final String frequency; // 'weekly' or 'monthly'
  final int? weekday; // 1=Monday ... 7=Sunday (for weekly)
  final int? monthDay; // 1-31 (for monthly)
  final String note;
  final bool enabled;
  final String? lastProcessedDate;

  RecurringPayday({
    this.id,
    required this.amount,
    required this.frequency,
    this.weekday,
    this.monthDay,
    required this.note,
    this.enabled = true,
    this.lastProcessedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'frequency': frequency,
      'weekday': weekday,
      'month_day': monthDay,
      'note': note,
      'enabled': enabled ? 1 : 0,
      'last_processed_date': lastProcessedDate,
    };
  }

  factory RecurringPayday.fromMap(Map<String, dynamic> map) {
    return RecurringPayday(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      frequency: map['frequency'] as String,
      weekday: map['weekday'] as int?,
      monthDay: map['month_day'] as int?,
      note: map['note'] as String,
      enabled: (map['enabled'] as int) == 1,
      lastProcessedDate: map['last_processed_date'] as String?,
    );
  }

  RecurringPayday copyWith({
    int? id,
    double? amount,
    String? frequency,
    int? weekday,
    int? monthDay,
    String? note,
    bool? enabled,
    String? lastProcessedDate,
  }) {
    return RecurringPayday(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      weekday: weekday ?? this.weekday,
      monthDay: monthDay ?? this.monthDay,
      note: note ?? this.note,
      enabled: enabled ?? this.enabled,
      lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
    );
  }
}
