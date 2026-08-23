import 'budget_record.dart';
import 'subscription_record.dart';
import 'transaction_record.dart';

class WalletSnapshot {
  const WalletSnapshot({
    required this.transactions,
    required this.budgets,
    required this.subscriptions,
  });

  final List<TransactionRecord> transactions;
  final List<BudgetRecord> budgets;
  final List<SubscriptionRecord> subscriptions;

  WalletSnapshot copyWith({
    List<TransactionRecord>? transactions,
    List<BudgetRecord>? budgets,
    List<SubscriptionRecord>? subscriptions,
  }) {
    return WalletSnapshot(
      transactions: transactions ?? this.transactions,
      budgets: budgets ?? this.budgets,
      subscriptions: subscriptions ?? this.subscriptions,
    );
  }
}
