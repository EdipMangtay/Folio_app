import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/domain/tour/tour_step.dart';
import 'package:folio_wallet/presentation/shell/app_shell.dart';
import 'package:folio_wallet/presentation/tour/tour_anchor.dart';
import 'package:folio_wallet/presentation/tour/tour_overlay.dart';
import 'package:folio_wallet/state/settings_controller.dart';
import 'package:folio_wallet/state/wallet_controller.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';

late FakeWallet wallet;
late FakeSettings settings;

const List<String> _screens = <String>['Ana', 'İşlemler', 'Analiz', 'Profil'];

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Boots the real shell over four stand-in branch screens.
Future<void> _open(WidgetTester tester, {bool seen = false}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  wallet = FakeWallet();
  settings = FakeSettings(hasSeenOnboarding: seen);

  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      StatefulShellRoute(
        builder: (BuildContext c, GoRouterState s, StatefulNavigationShell n) => n,
        navigatorContainerBuilder: (
          BuildContext c,
          StatefulNavigationShell n,
          List<Widget> children,
        ) =>
            AppShell(navigationShell: n, children: children),
        branches: <StatefulShellBranch>[
          for (final String name in _screens)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: name == 'Ana' ? '/' : '/${_screens.indexOf(name)}',
                  builder: (BuildContext c, GoRouterState s) =>
                      Center(child: Text('$name ekranı')),
                ),
              ],
            ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        walletProvider.overrideWith(() => wallet),
        settingsProvider.overrideWith(() => settings),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await _settle(tester);
}

Future<void> _advance(WidgetTester tester) async {
  final Finder next = find.text('İleri');
  await tester.tap(next.evaluate().isEmpty ? find.text('Bitir') : next);
  await _settle(tester);
}

void main() {
  testWidgets('a first run opens the tour on the income step', (WidgetTester tester) async {
    await _open(tester);

    expect(find.byType(TourOverlay), findsOneWidget);
    expect(find.text('Gelirini gir.'), findsOneWidget);
  });

  testWidgets('a later run does not start the tour', (WidgetTester tester) async {
    await _open(tester, seen: true);
    expect(find.byType(TourOverlay), findsNothing);
  });

  testWidgets('saving income stores one record and moves on', (WidgetTester tester) async {
    await _open(tester);

    await tester.enterText(find.byType(TextField).first, '62000');
    await _settle(tester);
    await tester.tap(find.text('Kaydet ve devam et'));
    await _settle(tester);

    expect(wallet.added.length, 1);
    expect(wallet.added.single.type, TransactionType.income);
    expect(wallet.added.single.amount, 62000);
    expect(find.text('Gelirini gir.'), findsNothing);
  });

  testWidgets('skipping income stores nothing and still moves on', (
    WidgetTester tester,
  ) async {
    await _open(tester);

    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    expect(wallet.added, isEmpty);
    expect(find.byType(TourOverlay), findsOneWidget);
    expect(find.text('Gelirini gir.'), findsNothing);
  });

  testWidgets('each stop leaves the shell on the tab it declares', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    for (int i = 1; i < kTourSteps.length; i++) {
      final TourSpotlightStep step = kTourSteps[i] as TourSpotlightStep;
      expect(
        find.text('${_screens[step.tab]} ekranı'),
        findsOneWidget,
        reason: '${step.title} adımı ${step.tab}. sekmede olmalıydı',
      );
      await _advance(tester);
    }
  });

  testWidgets('walking to the end closes the tour and records it as seen', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    for (int i = 1; i < kTourSteps.length; i++) {
      await _advance(tester);
    }

    expect(find.byType(TourOverlay), findsNothing);
    expect(settings.onboardingCompleted, isTrue);
  });

  testWidgets('Geç ends the tour at any point and records it as seen', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    await tester.tap(find.text('Geç'));
    await _settle(tester);

    expect(find.byType(TourOverlay), findsNothing);
    expect(settings.onboardingCompleted, isTrue);
  });

  testWidgets('the highlight lands on the control the step names', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    // The branch screens here are stand-ins, so only the dock's own targets
    // exist. Walk to the first stop that names one.
    const TourTarget expected = TourTarget.homeTab;
    final int index = kTourSteps.indexWhere(
      (TourStep step) => step is TourSpotlightStep && step.target == expected,
    );
    for (int i = 1; i < index; i++) {
      await _advance(tester);
    }

    final TourOverlay overlay = tester.widget<TourOverlay>(find.byType(TourOverlay));
    final Rect anchored = tester.getRect(
      find.byWidgetPredicate((Widget w) => w is TourAnchor && w.target == expected),
    );
    expect(overlay.highlight, isNotNull);
    expect((overlay.highlight!.center - anchored.center).distance, lessThan(1));
    expect(overlay.highlight!.size, anchored.size);
  });
}
