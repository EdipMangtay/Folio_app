import 'package:sqflite/sqflite.dart';

import '../../domain/models/budget_record.dart';
import '../../domain/models/transaction_record.dart';
import '../demo/demo_data.dart';

/// Local SQLite storage.
///
/// The file lives in the app's private directory on the device. Nothing is
/// uploaded and no account is required — clearing the app data removes it.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const int _schemaVersion = 2;

  Database? _database;

  Future<Database> get database async {
    final Database? existing = _database;
    if (existing != null) return existing;
    final String root = await getDatabasesPath();
    final Database opened = await openDatabase(
      '$root/folio_wallet.db',
      version: _schemaVersion,
      onCreate: (Database db, int version) async {
        await _createSchema(db);
        await _seedBudgets(db);
      },
      onUpgrade: _upgrade,
    );
    _database = opened;
    return opened;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<void> _createSchema(Database db) async {
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
  }

  /// v1 auto-seeded 112 demo transactions into every wallet and kept a static
  /// subscription table. Both are gone: demo data is now opt-in and
  /// subscriptions are derived from the transactions themselves.
  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.delete('transactions', where: 'source = ?', whereArgs: <Object?>['demo']);
      await db.execute('DROP TABLE IF EXISTS subscriptions');
    }
  }

  Future<void> _seedBudgets(Database db) async {
    final Batch batch = db.batch();
    for (final BudgetRecord item in DemoData.budgets()) {
      batch.insert('budgets', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<void> upsertTransaction(TransactionRecord transaction) async {
    final Database db = await database;
    await db.insert('transactions', transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Writes a whole import in one transaction so a failure halfway through
  /// cannot leave a partially imported statement behind.
  Future<void> upsertTransactions(Iterable<TransactionRecord> transactions) async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      final Batch batch = txn.batch();
      for (final TransactionRecord transaction in transactions) {
        batch.insert('transactions', transaction.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteTransaction(String id) async {
    final Database db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> upsertBudget(BudgetRecord budget) async {
    final Database db = await database;
    await db.insert('budgets', budget.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> transactionCount() async {
    final Database db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transactions')) ?? 0;
  }

  /// Replaces everything with the sample wallet. Explicit, never automatic.
  Future<void> loadDemoData() async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      await txn.delete('transactions');
      final Batch batch = txn.batch();
      for (final TransactionRecord item in DemoData.transactions()) {
        batch.insert('transactions', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final BudgetRecord item in DemoData.budgets()) {
        batch.insert('budgets', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Removes every stored transaction and restores the default budgets.
  Future<void> clearAllData() async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      await txn.delete('transactions');
      await txn.delete('budgets');
      final Batch batch = txn.batch();
      for (final BudgetRecord item in DemoData.budgets()) {
        batch.insert('budgets', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }
}
