import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/wallet_repository.dart';
import '../domain/models/budget_record.dart';
import '../domain/models/goal_record.dart';
import '../domain/models/transaction_record.dart';
import '../domain/models/wallet_snapshot.dart';

final Provider<WalletRepository> walletRepositoryProvider = Provider<WalletRepository>(
  (Ref ref) => WalletRepository(AppDatabase.instance),
);

final AsyncNotifierProvider<WalletController, WalletSnapshot> walletProvider =
    AsyncNotifierProvider<WalletController, WalletSnapshot>(WalletController.new);

class WalletController extends AsyncNotifier<WalletSnapshot> {
  WalletRepository get _repository => ref.read(walletRepositoryProvider);

  @override
  Future<WalletSnapshot> build() async {
    await _repository.initialize();
    return _repository.load();
  }

  Future<void> refresh() async {
    try {
      state = AsyncData<WalletSnapshot>(await _repository.load());
    } catch (error, stackTrace) {
      state = AsyncError<WalletSnapshot>(error, stackTrace);
    }
  }

  Future<void> addTransaction(TransactionRecord transaction) async {
    await _repository.saveTransaction(transaction);
    await refresh();
  }

  Future<void> updateTransaction(TransactionRecord transaction) async {
    await _repository.saveTransaction(transaction);
    await refresh();
  }

  Future<void> addTransactions(Iterable<TransactionRecord> transactions) async {
    if (transactions.isEmpty) return;
    await _repository.saveTransactions(transactions);
    await refresh();
  }

  Future<void> deleteTransaction(String id) async {
    await _repository.deleteTransaction(id);
    await refresh();
  }

  Future<void> saveBudget(BudgetRecord budget) async {
    await _repository.saveBudget(budget);
    await refresh();
  }

  Future<void> deleteBudget(String id) async {
    await _repository.deleteBudget(id);
    await refresh();
  }

  Future<void> saveGoal(GoalRecord goal) async {
    await _repository.saveGoal(goal);
    await refresh();
  }

  Future<void> deleteGoal(String id) async {
    await _repository.deleteGoal(id);
    await refresh();
  }

  Future<void> contributeToGoal(String id, double deltaAmount) async {
    final WalletSnapshot? current = state.value;
    if (current == null) return;
    for (final GoalRecord item in current.goals) {
      if (item.id == id) {
        final double newSaved = (item.savedAmount + deltaAmount).clamp(0.0, 999999999.0);
        await _repository.saveGoal(item.copyWith(savedAmount: newSaved));
        await refresh();
        break;
      }
    }
  }

  Future<void> loadDemoData() async {
    await _repository.loadDemoData();
    await refresh();
  }

  Future<void> clearAllData() async {
    await _repository.clearAllData();
    await refresh();
  }

  Future<void> restoreFromBackup(WalletSnapshot backup) async {
    await _repository.restoreFromBackup(
      transactions: backup.transactions,
      budgets: backup.budgets,
      goals: backup.goals,
    );
    await refresh();
  }
}
