import '../../domain/analytics/subscription_detector.dart';
import '../../domain/models/budget_record.dart';
import '../../domain/models/goal_record.dart';
import '../../domain/models/subscription_record.dart';
import '../../domain/models/transaction_record.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../database/app_database.dart';

class WalletRepository {
  WalletRepository(this._database);

  final AppDatabase _database;

  Future<void> initialize() => _database.initialize();

  Future<WalletSnapshot> load() async {
    final List<TransactionRecord> transactions = await _database.getTransactions();
    final List<BudgetRecord> budgets = await _database.getBudgets();
    final List<GoalRecord> goals = await _database.getGoals();
    final List<SubscriptionRecord> subscriptions = SubscriptionDetector.detect(transactions);
    return WalletSnapshot(
      transactions: transactions,
      budgets: budgets,
      subscriptions: subscriptions,
      goals: goals,
    );
  }

  Future<void> saveTransaction(TransactionRecord transaction) =>
      _database.upsertTransaction(transaction);

  Future<void> saveTransactions(Iterable<TransactionRecord> transactions) =>
      _database.upsertTransactions(transactions);

  Future<void> deleteTransaction(String id) => _database.deleteTransaction(id);

  Future<void> saveBudget(BudgetRecord budget) => _database.upsertBudget(budget);

  Future<void> deleteBudget(String id) => _database.deleteBudget(id);

  Future<void> saveGoal(GoalRecord goal) => _database.upsertGoal(goal);

  Future<void> deleteGoal(String id) => _database.deleteGoal(id);

  Future<void> loadDemoData() => _database.loadDemoData();

  Future<void> clearAllData() => _database.clearAllData();

  Future<void> restoreFromBackup({
    required List<TransactionRecord> transactions,
    required List<BudgetRecord> budgets,
    required List<GoalRecord> goals,
  }) =>
      _database.restoreFromBackup(transactions: transactions, budgets: budgets, goals: goals);
}
