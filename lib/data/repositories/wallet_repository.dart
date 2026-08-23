import '../../domain/models/budget_record.dart';
import '../../domain/models/subscription_record.dart';
import '../../domain/models/transaction_record.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../database/app_database.dart';

class WalletRepository {
  WalletRepository(this._database);

  final AppDatabase _database;

  Future<void> initialize() => _database.initialize();

  Future<WalletSnapshot> load() async {
    final Future<List<TransactionRecord>> transactionsFuture = _database.getTransactions();
    final Future<List<BudgetRecord>> budgetsFuture = _database.getBudgets();
    final Future<List<SubscriptionRecord>> subscriptionsFuture = _database.getSubscriptions();
    return WalletSnapshot(
      transactions: await transactionsFuture,
      budgets: await budgetsFuture,
      subscriptions: await subscriptionsFuture,
    );
  }

  Future<void> saveTransaction(TransactionRecord transaction) =>
      _database.upsertTransaction(transaction);

  Future<void> deleteTransaction(String id) => _database.deleteTransaction(id);

  Future<void> saveBudget(BudgetRecord budget) => _database.upsertBudget(budget);

  Future<void> resetDemoData() => _database.resetDemoData();
}
