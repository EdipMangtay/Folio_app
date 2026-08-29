import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/domain/analytics/analytics_engine.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/presentation/widgets/financial_score_sheet.dart';

void main() {
  testWidgets('FinancialScoreSheet renders score and breakdown factors', (WidgetTester tester) async {
    final List<TransactionRecord> txs = <TransactionRecord>[
      TransactionRecord(
        id: '1',
        title: 'Maaş',
        amount: 30000,
        category: 'Maaş',
        date: DateTime.now(),
        type: TransactionType.income,
        source: TransactionSource.manual,
      ),
      TransactionRecord(
        id: '2',
        title: 'Kira',
        amount: 8000,
        category: 'Konut',
        date: DateTime.now(),
        type: TransactionType.expense,
        source: TransactionSource.manual,
      ),
    ];

    final WalletAnalytics analytics = AnalyticsEngine.compute(txs, now: DateTime.now());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinancialScoreSheet(analytics: analytics),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Finansal Denge Analizi'), findsOneWidget);
    expect(find.text('Tasarruf Oranı'), findsOneWidget);
    expect(find.text('Nakit Fazlası'), findsOneWidget);
  });
}
