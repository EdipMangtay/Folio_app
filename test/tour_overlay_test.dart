import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/domain/tour/tour_step.dart';
import 'package:folio_wallet/presentation/tour/tour_overlay.dart';
import 'package:folio_wallet/presentation/widgets/income_entry_card.dart';

const TourSpotlightStep _spot = TourSpotlightStep(
  tab: 2,
  target: TourTarget.analyticsTab,
  title: 'Analiz',
  body: 'Dönemin tüm görünümü.',
);

Future<void> _pump(
  WidgetTester tester, {
  required TourStep step,
  Rect? highlight,
  bool isLast = false,
  VoidCallback? onNext,
  VoidCallback? onSkip,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: TourOverlay(
          step: step,
          highlight: highlight,
          isLast: isLast,
          onNext: onNext ?? () {},
          onSkip: onSkip ?? () {},
          onIncome: (double a, String s) async {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a spotlight stop shows its title and body', (WidgetTester tester) async {
    await _pump(tester, step: _spot, highlight: const Rect.fromLTWH(10, 800, 80, 50));

    expect(find.text('Analiz'), findsOneWidget);
    expect(find.text('Dönemin tüm görünümü.'), findsOneWidget);
  });

  testWidgets('İleri and Geç are real, reachable buttons', (WidgetTester tester) async {
    int next = 0;
    int skip = 0;
    await _pump(
      tester,
      step: _spot,
      highlight: const Rect.fromLTWH(10, 800, 80, 50),
      onNext: () => next++,
      onSkip: () => skip++,
    );

    await tester.tap(find.text('İleri'));
    await tester.tap(find.text('Geç'));
    await tester.pump();

    expect(next, 1);
    expect(skip, 1);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'İleri')).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('the last stop offers Bitir instead of İleri', (WidgetTester tester) async {
    await _pump(
      tester,
      step: _spot,
      highlight: const Rect.fromLTWH(10, 800, 80, 50),
      isLast: true,
    );

    expect(find.text('Bitir'), findsOneWidget);
    expect(find.text('İleri'), findsNothing);
  });

  testWidgets('a stop with no measurable target still says its piece', (
    WidgetTester tester,
  ) async {
    // A missing highlight is a worse tour, not a crash.
    await _pump(tester, step: _spot);

    expect(find.text('Analiz'), findsOneWidget);
    expect(find.text('İleri'), findsOneWidget);
  });

  testWidgets('the form stop shows the income card, not a spotlight', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      step: const TourFormStep(title: 'Gelirini gir.', body: 'Tek bir kayıt yeter.'),
    );

    expect(find.byType(IncomeEntryCard), findsOneWidget);
    expect(find.text('Gelirini gir.'), findsOneWidget);
  });

  testWidgets('the scrim swallows taps meant for what is underneath', (
    WidgetTester tester,
  ) async {
    bool tappedBehind = false;
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              GestureDetector(
                onTap: () => tappedBehind = true,
                child: const SizedBox.expand(child: ColoredBox(color: Colors.white)),
              ),
              TourOverlay(
                step: _spot,
                highlight: const Rect.fromLTWH(10, 800, 80, 50),
                isLast: false,
                onNext: () {},
                onSkip: () {},
                onIncome: (double a, String s) async {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    expect(tappedBehind, isFalse);
  });
}
