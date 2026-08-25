import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/presentation/profile/profile_screen.dart';
import 'package:folio_wallet/state/settings_controller.dart';
import 'package:folio_wallet/state/tour_controller.dart';
import 'package:folio_wallet/state/wallet_controller.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('Profile can start the tour again', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late WidgetRef captured;
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext c, GoRouterState s) => Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              captured = ref;
              // In the app this screen sits inside AppShell's Scaffold, which
              // is what provides the Material its ink effects need.
              return const Scaffold(body: ProfileScreen());
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletProvider.overrideWith(FakeWallet.new),
          settingsProvider.overrideWith(() => FakeSettings(hasSeenOnboarding: true)),
        ],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(captured.read(tourProvider).running, isFalse);

    await tester.scrollUntilVisible(find.text('Turu tekrar izle'), 200);
    await tester.tap(find.text('Turu tekrar izle'));
    await tester.pump();

    expect(captured.read(tourProvider).running, isTrue);
    expect(captured.read(tourProvider).index, 0);
  });
}
