import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/domain/analytics/analytics_engine.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';

void main() {
  test('monthly analytics separates income and expense', () {
    final DateTime now = DateTime(2026, 8, 23);
    final List<TransactionRecord> items = <TransactionRecord>[
      TransactionRecord(
        id: '1',
        title: 'Gelir',
        category: 'Finans',
        amount: 50000,
        date: DateTime(2026, 8, 1),
        type: TransactionType.income,
        source: TransactionSource.demo,
      ),
      TransactionRecord(
        id: '2',
        title: 'Migros',
        merchant: 'Migros',
        category: 'Market',
        amount: 10000,
        date: DateTime(2026, 8, 5),
        type: TransactionType.expense,
        source: TransactionSource.demo,
      ),
      TransactionRecord(
        id: '3',
        title: 'Starbucks',
        merchant: 'Starbucks',
        category: 'Kahve',
        amount: 2000,
        date: DateTime(2026, 8, 6),
        type: TransactionType.expense,
        source: TransactionSource.demo,
      ),
    ];

    final WalletAnalytics result = AnalyticsEngine.compute(items, now: now);
    expect(result.monthIncome, 50000);
    expect(result.monthExpense, 12000);
    expect(result.savings, 38000);
    expect(result.categoryTotals['Market'], 10000);
  });
}
