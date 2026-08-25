import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/presentation/add/add_transaction_sheet.dart';
import 'package:folio_wallet/state/wallet_controller.dart';

import 'support/fakes.dart';

Future<void> _pumpSheet(WidgetTester tester, {TransactionType? initialType}) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [walletProvider.overrideWith(FakeWallet.new)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: initialType == null
              ? const AddTransactionSheet()
              : AddTransactionSheet(initialType: initialType),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on expense when nothing is asked for', (WidgetTester tester) async {
    await _pumpSheet(tester);
    expect(find.text('Yeni gider'), findsOneWidget);
  });

  testWidgets('opens on income when asked for', (WidgetTester tester) async {
    // Reaching the income form used to cost an extra tap on the segmented
    // control, which is why nothing on the dashboard could offer it directly.
    await _pumpSheet(tester, initialType: TransactionType.income);

    expect(find.text('Yeni gelir'), findsOneWidget);
    expect(find.text('Geliri ekle'), findsOneWidget);
  });

  testWidgets('the income form starts on an income category', (WidgetTester tester) async {
    await _pumpSheet(tester, initialType: TransactionType.income);
    expect(find.text('Kaynak / açıklama'), findsOneWidget);
  });
}
