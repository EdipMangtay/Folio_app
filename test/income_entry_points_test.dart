import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/domain/tour/tour_step.dart';
import 'package:folio_wallet/presentation/tour/tour_anchor.dart';
import 'package:folio_wallet/presentation/analytics/analytics_screen.dart';
import 'package:folio_wallet/presentation/dashboard/dashboard_screen.dart';
import 'package:folio_wallet/state/settings_controller.dart';
import 'package:folio_wallet/state/wallet_controller.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';

/// The income metric carries this in its semantics label, which also keeps the
/// finder off the cash-flow chart's "Gelir" legend.
final Finder _incomeMetric = find.bySemanticsLabel(RegExp('Gelir eklemek için dokun'));

TransactionRecord _expense(String id, DateTime date, double amount) => TransactionRecord(
      id: id,
      title: 'Migros',
      merchant: 'Migros',
      category: 'Market',
      amount: amount,
      date: date,
      type: TransactionType.expense,
      source: TransactionSource.statement,
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 450));
}

Future<void> _open(
  WidgetTester tester,
  Widget screen, {
  List<TransactionRecord> transactions = const <TransactionRecord>[],
}) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      // In the app these screens live inside AppShell's Scaffold, which is what
      // provides the Material ancestor their ink effects need.
      GoRoute(
        path: '/',
        builder: (BuildContext c, GoRouterState s) => Scaffold(body: screen),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        walletProvider.overrideWith(() => FakeWallet(transactions)),
        settingsProvider.overrideWith(FakeSettings.new),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await _settle(tester);
}

void main() {
  final List<TransactionRecord> july = <TransactionRecord>[
    _expense('1', DateTime(2026, 7, 4), 4200),
    _expense('2', DateTime(2026, 7, 18), 1300),
  ];

  testWidgets('the income figure on the dashboard opens the income form', (
    WidgetTester tester,
  ) async {
    // A wallet built only from a card statement has expenses and no income, so
    // the figure a user most wants to correct is the one reading 0 TL.
    await _open(tester, const DashboardScreen(), transactions: july);

    expect(_incomeMetric, findsOneWidget);
    await tester.tap(_incomeMetric);
    await _settle(tester);

    expect(find.text('Yeni gelir'), findsOneWidget);
  });

  testWidgets('the income figure on the analysis page opens the income form', (
    WidgetTester tester,
  ) async {
    await _open(tester, const AnalyticsScreen(), transactions: july);

    expect(_incomeMetric, findsOneWidget);
    await tester.tap(_incomeMetric);
    await _settle(tester);

    expect(find.text('Yeni gelir'), findsOneWidget);
  });

  testWidgets('the income figure is a large enough tap target', (WidgetTester tester) async {
    await _open(tester, const DashboardScreen(), transactions: july);

    final Size size = tester.getSize(
      find.descendant(of: _incomeMetric, matching: find.byType(InkWell)).first,
    );
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('an empty wallet offers entering income as a way to start', (
    WidgetTester tester,
  ) async {
    // The three ways to start were statement, receipt and demo data — none of
    // which lets somebody simply say what they earn.
    await _open(tester, const DashboardScreen());

    expect(find.text('Gelirini gir'), findsOneWidget);

    await tester.tap(find.text('Gelirini gir'));
    await _settle(tester);

    expect(find.text('Yeni gelir'), findsOneWidget);
  });

  testWidgets('the dashboard offers the controls the tour points at', (
    WidgetTester tester,
  ) async {
    // The tour highlights these by name; if the screen stops anchoring them,
    // those stops silently lose their cut-out.
    await _open(tester, const DashboardScreen(), transactions: july);

    for (final TourTarget target in <TourTarget>[
      TourTarget.periodSelector,
      TourTarget.incomeMetric,
    ]) {
      expect(
        find.byWidgetPredicate((Widget w) => w is TourAnchor && w.target == target),
        findsOneWidget,
        reason: '$target çapası ana sayfada yok',
      );
    }
  });
}
