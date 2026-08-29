import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/domain/tour/tour_step.dart';
import 'package:folio_wallet/presentation/shell/app_shell.dart';
import 'package:folio_wallet/presentation/tour/tour_overlay.dart';
import 'package:folio_wallet/state/settings_controller.dart';
import 'package:folio_wallet/state/tour_controller.dart';
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

Future<void> _boot(WidgetTester tester, {bool seen = false}) async {
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

void main() {
  testWidgets('full tour navigation flow with next and back buttons', (WidgetTester tester) async {
    await _boot(tester);

    // 1. Initial Step: Form Step
    expect(find.byType(TourOverlay), findsOneWidget);
    expect(find.text('Gelirini gir.'), findsOneWidget);

    // Skip income to move to step 2 (spotlight 1)
    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    // 2. Spotlight Step 2/9 (index 1)
    expect(find.text('2/9'), findsOneWidget);
    expect(find.text('Önce dönemi seç'), findsOneWidget);
    expect(find.byTooltip('Önceki'), findsOneWidget);

    // Tap "İleri" -> Step 3/9 (index 2)
    await tester.tap(find.text('İleri'));
    await _settle(tester);
    expect(find.text('3/9'), findsOneWidget);
    expect(find.text('Gelirini buradan ekle'), findsOneWidget);

    // Test "Önceki" button -> back to 2/9
    await tester.tap(find.byTooltip('Önceki'));
    await _settle(tester);
    expect(find.text('2/9'), findsOneWidget);
    expect(find.text('Önce dönemi seç'), findsOneWidget);

    // Walk forward through all remaining steps to the end
    for (int i = 2; i < kTourSteps.length; i++) {
      await tester.tap(find.text('İleri'));
      await _settle(tester);
      expect(find.text('${i + 1}/${kTourSteps.length}'), findsOneWidget);
    }

    // On last step (9/9)
    expect(find.text('Bitir'), findsOneWidget);
    expect(find.text('İleri'), findsNothing);

    // Finish tour
    await tester.tap(find.text('Bitir'));
    await _settle(tester);

    expect(find.byType(TourOverlay), findsNothing);
    expect(settings.onboardingCompleted, isTrue);
  });
}
