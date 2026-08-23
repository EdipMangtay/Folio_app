import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/wallet_repository.dart';
import '../domain/models/budget_record.dart';
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

  Future<void> addTransactions(Iterable<TransactionRecord> transactions) async {
    for (final TransactionRecord transaction in transactions) {
      await _repository.saveTransaction(transaction);
    }
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

  Future<void> resetDemoData() async {
    await _repository.resetDemoData();
    await refresh();
  }
}
