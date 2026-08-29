import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/presentation/dashboard/dashboard_screen.dart';
import 'package:folio_wallet/state/settings_controller.dart';
import 'package:folio_wallet/state/wallet_controller.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('Dashboard masks balances when hideBalances is enabled', (WidgetTester tester) async {
    final List<TransactionRecord> txs = <TransactionRecord>[
      TransactionRecord(
        id: '1',
        title: 'Maaş',
        amount: 25000,
        category: 'Maaş',
        date: DateTime.now(),
        type: TransactionType.income,
        source: TransactionSource.manual,
      ),
      TransactionRecord(
        id: '2',
        title: 'Market',
        amount: 4500,
        category: 'Market',
        date: DateTime.now(),
        type: TransactionType.expense,
        source: TransactionSource.manual,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletProvider.overrideWith(() => FakeWallet(txs)),
          settingsProvider.overrideWith(() => FakeSettings(hasSeenOnboarding: true, hideBalances: true)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DashboardScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('•••• ₺'), findsWidgets);
  });
}
