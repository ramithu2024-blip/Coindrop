class Payday {
  final int? id;
  final double amount;
  final String note;
  final String date;

  Payday({
    this.id,
    required this.amount,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'note': note,
      'date': date,
    };
  }

  factory Payday.fromMap(Map<String, dynamic> map) {
    return Payday(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String,
      date: map['date'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'amount': amount, 'note': note, 'date': date};
  }
}
