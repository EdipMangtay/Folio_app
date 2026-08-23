class SubscriptionRecord {
  const SubscriptionRecord({
    required this.id,
    required this.merchant,
    required this.category,
    required this.monthlyAmount,
    required this.nextBillingDate,
  });

  final String id;
  final String merchant;
  final String category;
  final double monthlyAmount;
  final DateTime nextBillingDate;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'merchant': merchant,
        'category': category,
        'monthly_amount': monthlyAmount,
        'next_billing_date': nextBillingDate.toIso8601String(),
      };

  factory SubscriptionRecord.fromMap(Map<String, Object?> map) => SubscriptionRecord(
        id: map['id']! as String,
        merchant: map['merchant']! as String,
        category: map['category']! as String,
        monthlyAmount: (map['monthly_amount']! as num).toDouble(),
        nextBillingDate: DateTime.parse(map['next_billing_date']! as String),
      );
}
