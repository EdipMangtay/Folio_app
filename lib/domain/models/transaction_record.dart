enum TransactionType { expense, income }

enum TransactionSource { manual, receipt, statement, demo }

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.type,
    required this.source,
    this.merchant,
    this.paymentLabel,
    this.note,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final TransactionSource source;
  final String? merchant;
  final String? paymentLabel;
  final String? note;

  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;

  TransactionRecord copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    DateTime? date,
    TransactionType? type,
    TransactionSource? source,
    String? merchant,
    String? paymentLabel,
    String? note,
  }) {
    return TransactionRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      source: source ?? this.source,
      merchant: merchant ?? this.merchant,
      paymentLabel: paymentLabel ?? this.paymentLabel,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'type': type.name,
        'source': source.name,
        'merchant': merchant,
        'payment_label': paymentLabel,
        'note': note,
      };

  factory TransactionRecord.fromMap(Map<String, Object?> map) {
    return TransactionRecord(
      id: map['id']! as String,
      title: map['title']! as String,
      category: map['category']! as String,
      amount: (map['amount']! as num).toDouble(),
      date: DateTime.parse(map['date']! as String),
      type: TransactionType.values.byName(map['type']! as String),
      source: TransactionSource.values.byName(map['source']! as String),
      merchant: map['merchant'] as String?,
      paymentLabel: map['payment_label'] as String?,
      note: map['note'] as String?,
    );
  }
}
