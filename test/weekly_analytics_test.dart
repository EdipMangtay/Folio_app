import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/domain/analytics/weekly_analytics.dart';
import 'package:folio_wallet/domain/models/budget_record.dart';
import 'package:folio_wallet/domain/models/subscription_record.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/domain/models/wallet_snapshot.dart';
import 'package:folio_wallet/services/notification_service.dart';

void main() {
  group('WeeklyAnalyticsEngine', () {
    test('computes weekly expense, income and daily series accurately', () {
      final DateTime wednesday = DateTime(2026, 8, 26); // Wednesday
      final List<TransactionRecord> txs = <TransactionRecord>[
        TransactionRecord(
          id: '1',
          title: 'Migros',
          amount: 1200,
          category: 'Market',
          date: DateTime(2026, 8, 24), // Monday
          type: TransactionType.expense,
          source: TransactionSource.manual,
        ),
        TransactionRecord(
          id: '2',
          title: 'Maaş',
          amount: 20000,
          category: 'Maaş',
          date: DateTime(2026, 8, 25), // Tuesday
          type: TransactionType.income,
          source: TransactionSource.manual,
        ),
        TransactionRecord(
          id: '3',
          title: 'Restoran',
          amount: 800,
          category: 'Yeme & İçme',
          date: DateTime(2026, 8, 26), // Wednesday
          type: TransactionType.expense,
          source: TransactionSource.manual,
        ),
        // Previous week transaction
        TransactionRecord(
          id: '4',
          title: 'Eski Market',
          amount: 2500,
          category: 'Market',
          date: DateTime(2026, 8, 19), // Previous Wednesday
          type: TransactionType.expense,
          source: TransactionSource.manual,
        ),
      ];

      final WeeklyAnalytics result = WeeklyAnalyticsEngine.compute(txs, now: wednesday);

      expect(result.weekExpense, 2000); // 1200 + 800
      expect(result.weekIncome, 20000);
      expect(result.previousWeekExpense, 2500);
      expect(result.changePercent, ((2000 - 2500) / 2500) * 100);
      expect(result.topCategory, 'Market');
      expect(result.topCategoryAmount, 1200);
      expect(result.topMerchant, 'Migros');
      expect(result.dailySeries.length, 7);
      expect(result.topTransaction?.title, 'Migros');
    });

    test('generates dynamic notification body with real data', () {
      final List<TransactionRecord> txs = <TransactionRecord>[
        TransactionRecord(
          id: '1',
          title: 'Starbucks',
          amount: 350,
          category: 'Kahve',
          date: DateTime.now(),
          type: TransactionType.expense,
          source: TransactionSource.manual,
        ),
      ];

      final WalletSnapshot snapshot = WalletSnapshot(
        transactions: txs,
        budgets: const <BudgetRecord>[],
        subscriptions: const <SubscriptionRecord>[],
      );

      final String body = NotificationService.instance.buildWeeklyDigestBody(snapshot);
      expect(body, contains('350'));
      expect(body, contains('Kahve'));
    });
  });
}
