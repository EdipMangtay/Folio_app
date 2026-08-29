import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/domain/models/budget_record.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/presentation/widgets/category_detail_sheet.dart';

void main() {
  testWidgets('CategoryDetailSheet renders category stats and transactions', (WidgetTester tester) async {
    final List<TransactionRecord> txs = <TransactionRecord>[
      TransactionRecord(
        id: '1',
        title: 'Migros',
        amount: 850,
        category: 'Market',
        date: DateTime.now(),
        type: TransactionType.expense,
        source: TransactionSource.manual,
      ),
      TransactionRecord(
        id: '2',
        title: 'Carrefour',
        amount: 650,
        category: 'Market',
        date: DateTime.now(),
        type: TransactionType.expense,
        source: TransactionSource.manual,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryDetailSheet(
            category: 'Market',
            amount: 1500,
            totalExpense: 6000,
            transactions: txs,
            budget: const BudgetRecord(id: 'b1', category: 'Market', limitAmount: 3000),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Market'), findsWidgets);
    expect(find.text('Kategori Detayı ve Harcamalar'), findsOneWidget);
    expect(find.text('TOPLAM HARCAMA'), findsOneWidget);
    expect(find.text('Migros'), findsOneWidget);
    expect(find.text('Carrefour'), findsOneWidget);
  });
}
