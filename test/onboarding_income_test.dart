import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/presentation/onboarding/onboarding_screen.dart';
import 'package:folio_wallet/state/settings_controller.dart';
import 'package:folio_wallet/state/wallet_controller.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';

/// MoneyPulse breathes on a repeating controller, so the tree never goes quiet
/// and pumpAndSettle would wait forever. Pump a fixed span instead.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 450));
}

late FakeWallet wallet;
late FakeSettings settings;

Future<void> _openOnboarding(WidgetTester tester, {Size size = const Size(420, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  wallet = FakeWallet();
  settings = FakeSettings();

  final GoRouter router = GoRouter(
    initialLocation: '/onboarding',
    routes: <RouteBase>[
      GoRoute(path: '/onboarding', builder: (BuildContext c, GoRouterState s) => const OnboardingScreen()),
      GoRoute(path: '/', builder: (BuildContext c, GoRouterState s) => const Scaffold(body: Text('cüzdan'))),
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

/// Walks to the last slide using the primary button.
Future<void> _goToIncomeStep(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    if (find.byType(TextField).evaluate().isNotEmpty) return;
    await tester.tap(find.text('Devam et'));
    await _settle(tester);
  }
  fail('gelir adımına ulaşılamadı');
}

void main() {
  testWidgets('the tour ends on a step that asks for income', (WidgetTester tester) async {
    await _openOnboarding(tester);
    await _goToIncomeStep(tester);

    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Şimdilik geç'), findsOneWidget);
  });

  testWidgets('a valid amount is stored as an income transaction', (WidgetTester tester) async {
    await _openOnboarding(tester);
    await _goToIncomeStep(tester);

    await tester.enterText(find.byType(TextField).first, '62.000');
    await _settle(tester);
    await tester.tap(find.text('Kaydet ve başla'));
    await _settle(tester);

    expect(wallet.added.length, 1);
    final TransactionRecord saved = wallet.added.single;
    expect(saved.type, TransactionType.income);
    expect(saved.amount, 62000);
    expect(saved.category, 'Maaş');
    expect(saved.source, TransactionSource.manual);
    expect(settings.onboardingCompleted, isTrue);
  });

  testWidgets('the given source names the record', (WidgetTester tester) async {
    await _openOnboarding(tester);
    await _goToIncomeStep(tester);

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '15000');
    await tester.enterText(fields.at(1), 'Freelance iş');
    await _settle(tester);
    await tester.tap(find.text('Kaydet ve başla'));
    await _settle(tester);

    expect(wallet.added.single.title, 'Freelance iş');
  });

  testWidgets('skipping stores nothing but still finishes the tour', (WidgetTester tester) async {
    await _openOnboarding(tester);
    await _goToIncomeStep(tester);

    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    expect(wallet.added, isEmpty);
    expect(settings.onboardingCompleted, isTrue);
  });

  testWidgets('an empty amount is refused rather than saved as zero', (WidgetTester tester) async {
    await _openOnboarding(tester);
    await _goToIncomeStep(tester);

    await tester.tap(find.text('Kaydet ve başla'));
    await _settle(tester);

    expect(wallet.added, isEmpty);
    expect(settings.onboardingCompleted, isFalse);
    expect(find.text('Bir tutar gir.'), findsOneWidget);
  });

  testWidgets('the refusal never covers the way out of the step', (WidgetTester tester) async {
    // A snackbar sat over the bottom of the screen naming the very button it
    // was hiding. The message belongs under the field it is about.
    await _openOnboarding(tester);
    await _goToIncomeStep(tester);

    await tester.tap(find.text('Kaydet ve başla'));
    await _settle(tester);

    expect(find.byType(SnackBar), findsNothing);

    // Still reachable: tapping it finishes the tour.
    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);
    expect(settings.onboardingCompleted, isTrue);
  });

  testWidgets('typing clears the refusal', (WidgetTester tester) async {
    await _openOnboarding(tester);
    await _goToIncomeStep(tester);

    await tester.tap(find.text('Kaydet ve başla'));
    await _settle(tester);
    expect(find.text('Bir tutar gir.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '5000');
    await _settle(tester);
    expect(find.text('Bir tutar gir.'), findsNothing);
  });

  testWidgets('an unreadable amount is refused', (WidgetTester tester) async {
    await _openOnboarding(tester);
    await _goToIncomeStep(tester);

    await tester.enterText(find.byType(TextField).first, 'abc');
    await _settle(tester);
    await tester.tap(find.text('Kaydet ve başla'));
    await _settle(tester);

    expect(wallet.added, isEmpty);
    expect(settings.onboardingCompleted, isFalse);
    expect(find.text('Geçerli bir tutar gir.'), findsOneWidget);
  });

  testWidgets('a negative amount is refused', (WidgetTester tester) async {
    await _openOnboarding(tester);
    await _goToIncomeStep(tester);

    await tester.enterText(find.byType(TextField).first, '-500');
    await _settle(tester);
    await tester.tap(find.text('Kaydet ve başla'));
    await _settle(tester);

    expect(wallet.added, isEmpty);
  });

  testWidgets('the income step fits a small phone without overflowing', (
    WidgetTester tester,
  ) async {
    // 320x568 is the smallest screen worth supporting; the step carries a card,
    // a heading, a paragraph and two buttons. An overflow throws here.
    await _openOnboarding(tester, size: const Size(320, 568));
    await _goToIncomeStep(tester);

    expect(find.text('Kaydet ve başla'), findsOneWidget);
    expect(find.text('Şimdilik geç'), findsOneWidget);
  });

  testWidgets('every slide of the tour renders on a small phone', (WidgetTester tester) async {
    await _openOnboarding(tester, size: const Size(320, 568));

    for (int i = 0; i < 3; i++) {
      expect(find.text('Devam et'), findsOneWidget);
      await tester.tap(find.text('Devam et'));
      await _settle(tester);
    }
    expect(find.text('Kaydet ve başla'), findsOneWidget);
  });

  testWidgets('reduced motion skips the entrance animation entirely', (
    WidgetTester tester,
  ) async {
    // With animations disabled the content must be laid out plainly, not
    // wrapped in something that fades it in from nothing.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _openOnboarding(tester);

    expect(find.byType(Opacity), findsNothing);
    expect(find.text('Devam et'), findsOneWidget);
  });

  testWidgets('the slide is fully arrived once the stagger has run', (
    WidgetTester tester,
  ) async {
    await _openOnboarding(tester);
    await _goToIncomeStep(tester);

    // Scoped to the slide on screen: the neighbouring page the PageView has
    // built is legitimately transparent while it is a full page away.
    for (final Element e in find
        .ancestor(of: find.text('Gelirini gir.'), matching: find.byType(Opacity))
        .evaluate()) {
      expect((e.widget as Opacity).opacity, 1.0);
    }
  });
}
