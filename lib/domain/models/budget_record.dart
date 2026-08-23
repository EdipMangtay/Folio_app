class BudgetRecord {
  const BudgetRecord({
    required this.id,
    required this.category,
    required this.limitAmount,
  });

  final String id;
  final String category;
  final double limitAmount;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'category': category,
        'limit_amount': limitAmount,
      };

  factory BudgetRecord.fromMap(Map<String, Object?> map) => BudgetRecord(
        id: map['id']! as String,
        category: map['category']! as String,
        limitAmount: (map['limit_amount']! as num).toDouble(),
      );
}
