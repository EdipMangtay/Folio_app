import 'package:sqflite/sqflite.dart';

import '../../domain/models/budget_record.dart';
import '../../domain/models/subscription_record.dart';
import '../../domain/models/transaction_record.dart';
import '../demo/demo_data.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    final Database? existing = _database;
    if (existing != null) return existing;
    final String root = await getDatabasesPath();
    final Database opened = await openDatabase(
      '$root/folio_wallet.db',
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE transactions(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            source TEXT NOT NULL,
            merchant TEXT,
            payment_label TEXT,
            note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE budgets(
            id TEXT PRIMARY KEY,
            category TEXT NOT NULL UNIQUE,
            limit_amount REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE subscriptions(
            id TEXT PRIMARY KEY,
            merchant TEXT NOT NULL,
            category TEXT NOT NULL,
            monthly_amount REAL NOT NULL,
            next_billing_date TEXT NOT NULL
          )
        ''');
      },
    );
    _database = opened;
    await _seedIfNeeded(opened);
    return opened;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<void> _seedIfNeeded(Database db) async {
    final int transactionCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM transactions'),
        ) ??
        0;
    if (transactionCount > 0) return;

    final Batch batch = db.batch();
    for (final TransactionRecord item in DemoData.transactions()) {
      batch.insert('transactions', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final BudgetRecord item in DemoData.budgets()) {
      batch.insert('budgets', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final SubscriptionRecord item in DemoData.subscriptions()) {
      batch.insert('subscriptions', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<TransactionRecord>> getTransactions() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query('transactions', orderBy: 'date DESC');
    return rows.map(TransactionRecord.fromMap).toList(growable: false);
  }

  Future<List<BudgetRecord>> getBudgets() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query('budgets', orderBy: 'category ASC');
    return rows.map(BudgetRecord.fromMap).toList(growable: false);
  }

  Future<List<SubscriptionRecord>> getSubscriptions() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query('subscriptions', orderBy: 'monthly_amount DESC');
    return rows.map(SubscriptionRecord.fromMap).toList(growable: false);
  }

  Future<void> upsertTransaction(TransactionRecord transaction) async {
    final Database db = await database;
    await db.insert('transactions', transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTransaction(String id) async {
    final Database db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> upsertBudget(BudgetRecord budget) async {
    final Database db = await database;
    await db.insert('budgets', budget.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> resetDemoData() async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('subscriptions');
    });
    await _seedIfNeeded(db);
  }
}
