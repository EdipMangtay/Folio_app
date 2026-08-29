import 'budget_record.dart';
import 'goal_record.dart';
import 'subscription_record.dart';
import 'transaction_record.dart';

class WalletSnapshot {
  const WalletSnapshot({
    required this.transactions,
    required this.budgets,
    required this.subscriptions,
    this.goals = const <GoalRecord>[],
  });

  final List<TransactionRecord> transactions;
  final List<BudgetRecord> budgets;
  final List<SubscriptionRecord> subscriptions;
  final List<GoalRecord> goals;

  WalletSnapshot copyWith({
    List<TransactionRecord>? transactions,
    List<BudgetRecord>? budgets,
    List<SubscriptionRecord>? subscriptions,
    List<GoalRecord>? goals,
  }) {
    return WalletSnapshot(
      transactions: transactions ?? this.transactions,
      budgets: budgets ?? this.budgets,
      subscriptions: subscriptions ?? this.subscriptions,
      goals: goals ?? this.goals,
    );
  }
}
