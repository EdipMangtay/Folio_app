import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/utils/formatters.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/presentation/transactions/transactions_screen.dart';
import 'package:folio_wallet/state/settings_controller.dart';
import 'package:folio_wallet/state/wallet_controller.dart';

import 'support/fakes.dart';

/// One small expense in the live month, one large one a month earlier. The
/// screen opens on the live month, so anything that reports 72.630 is counting
/// a month the user is not looking at.
List<TransactionRecord> _twoMonths() {
  final DateTime now = DateTime.now();
  return <TransactionRecord>[
    TransactionRecord(
      id: '1',
      title: 'Bu ayın fişi',
      amount: 630,
      category: 'Market',
      date: DateTime(now.year, now.month, 5),
      type: TransactionType.expense,
      source: TransactionSource.manual,
    ),
    TransactionRecord(
      id: '2',
      title: 'Geçen ayın harcaması',
      amount: 72000,
      category: 'Market',
      date: DateTime(now.year, now.month - 1, 5),
      type: TransactionType.expense,
      source: TransactionSource.manual,
    ),
  ];
}

Future<void> _pumpTransactions(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        walletProvider.overrideWith(() => FakeWallet(_twoMonths())),
        settingsProvider.overrideWith(() => FakeSettings(hasSeenOnboarding: true)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: TransactionsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the expense total leaves out months the user is not viewing', (WidgetTester tester) async {
    await _pumpTransactions(tester);

    expect(find.text(Formatters.money(72630)), findsNothing);
    expect(find.text(Formatters.money(630)), findsWidgets);
  });

  testWidgets('the list leaves out months the user is not viewing', (WidgetTester tester) async {
    await _pumpTransactions(tester);

    expect(find.text('Geçen ayın harcaması'), findsNothing);
    expect(find.text('Bu ayın fişi'), findsOneWidget);
  });
}
