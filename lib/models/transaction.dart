class Transaction {
  final int? id;
  final int envelopeId;
  final double amount;
  final String note;
  final String date;
  final String type; // 'funding' or 'spending'

  Transaction({
    this.id,
    required this.envelopeId,
    required this.amount,
    required this.note,
    required this.date,
    this.type = 'spending',
  });

  bool get isFunding => type == 'funding';
  bool get isSpending => type == 'spending';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'envelope_id': envelopeId,
      'amount': amount,
      'note': note,
      'date': date,
      'type': type,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      envelopeId: map['envelope_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String,
      date: map['date'] as String,
      type: map['type'] as String? ?? 'spending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'envelope_id': envelopeId,
      'amount': amount,
      'note': note,
      'date': date,
      'type': type,
    };
  }
}
