class Allocation {
  final int? id;
  final int paydayId;
  final int envelopeId;
  final double amount;

  Allocation({
    this.id,
    required this.paydayId,
    required this.envelopeId,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payday_id': paydayId,
      'envelope_id': envelopeId,
      'amount': amount,
    };
  }

  factory Allocation.fromMap(Map<String, dynamic> map) {
    return Allocation(
      id: map['id'] as int?,
      paydayId: map['payday_id'] as int,
      envelopeId: map['envelope_id'] as int,
      amount: (map['amount'] as num).toDouble(),
    );
  }
}
