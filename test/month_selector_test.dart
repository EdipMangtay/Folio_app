import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/domain/models/budget_record.dart';
import 'package:folio_wallet/domain/models/subscription_record.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/domain/models/wallet_snapshot.dart';
import 'package:folio_wallet/presentation/widgets/month_selector.dart';
import 'package:folio_wallet/state/month_scope_controller.dart';
import 'package:folio_wallet/state/wallet_controller.dart';

class _FakeWallet extends WalletController {
  _FakeWallet(this._transactions);

  final List<TransactionRecord> _transactions;

  @override
  Future<WalletSnapshot> build() async => WalletSnapshot(
        transactions: _transactions,
        budgets: const <BudgetRecord>[],
        subscriptions: const <SubscriptionRecord>[],
      );
}

TransactionRecord _tx(String id, DateTime date) => TransactionRecord(
      id: id,
      title: 'Kayit $id',
      merchant: 'Kayit $id',
      category: 'Market',
      amount: 1250,
      date: date,
      type: TransactionType.expense,
      source: TransactionSource.statement,
    );

/// Mirrors the dashboard hero row: the selector shares a line with the
/// month-over-month delta, which is the tightest place it has to fit.
Widget _heroRow({required bool dense}) {
  return Row(
    children: <Widget>[
      MonthSelector(dense: dense),
      const Spacer(),
      const Icon(Icons.south_east_rounded, size: 15),
      const SizedBox(width: 6),
      const Text('%12,3'),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<TransactionRecord> transactions = const <TransactionRecord>[],
  Size size = const Size(320, 720),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      // `Override` is not exported by flutter_riverpod 3, so this list is inferred.
      overrides: [walletProvider.overrideWith(() => _FakeWallet(transactions))],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final List<TransactionRecord> july = <TransactionRecord>[
    _tx('1', DateTime(2026, 7, 4)),
    _tx('2', DateTime(2026, 7, 21)),
  ];

  testWidgets('the dense selector fits the hero row on a 320px screen', (WidgetTester tester) async {
    await _pump(tester, _heroRow(dense: true), transactions: july);
    // pumpAndSettle rethrows overflow errors, so reaching here means it fit.
    expect(find.byType(MonthSelector), findsOneWidget);
    expect(find.text('%12,3'), findsOneWidget);
  });

  testWidgets('the full selector fits a narrow screen', (WidgetTester tester) async {
    await _pump(tester, const MonthSelector(), transactions: july);
    expect(find.byType(MonthSelector), findsOneWidget);
  });

  testWidgets('both arrows meet the 44px minimum tap target', (WidgetTester tester) async {
    await _pump(tester, const MonthSelector(), transactions: july);

    for (final String label in <String>['Önceki ay', 'Sonraki ay']) {
      final Size size = tester.getSize(
        find.descendant(of: find.bySemanticsLabel(label), matching: find.byType(SizedBox)).first,
      );
      expect(size.width, greaterThanOrEqualTo(44), reason: '$label çok dar');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$label çok kısa');
    }
  });

  testWidgets('the month reads as a button, not a caption', (WidgetTester tester) async {
    await _pump(tester, const MonthSelector(), transactions: july);

    // A chevron is the affordance that says the period can be changed.
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    expect(
      tester.getSize(find.byType(InkWell).at(1)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('opens on the newest month holding data, not an empty live month', (
    WidgetTester tester,
  ) async {
    late DateTime selected;
    await _pump(
      tester,
      Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          selected = ref.watch(selectedMonthProvider);
          return const MonthSelector();
        },
      ),
      transactions: july,
    );

    // July 2026 is the only month with data; today is well past it.
    expect(selected, DateTime(2026, 7));
    expect(find.text('Temmuz 2026'), findsOneWidget);
  });

  testWidgets('tapping the month opens the period sheet', (WidgetTester tester) async {
    await _pump(tester, const MonthSelector(), transactions: july, size: const Size(390, 844));

    await tester.tap(find.text('Temmuz 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Dönem seç'), findsOneWidget);
    expect(find.text('Temmuz'), findsOneWidget);
  });

  testWidgets('the sheet marks which months hold data', (WidgetTester tester) async {
    await _pump(tester, const MonthSelector(), transactions: july, size: const Size(390, 844));

    await tester.tap(find.text('Temmuz 2026'));
    await tester.pumpAndSettle();

    expect(find.text('2 işlem'), findsOneWidget);
    expect(find.text('işlem yok'), findsWidgets);
  });
}
