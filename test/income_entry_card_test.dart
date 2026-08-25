import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/presentation/widgets/income_entry_card.dart';

Future<void> _pump(
  WidgetTester tester, {
  required void Function(double, String) onSubmit,
  required VoidCallback onSkip,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: IncomeEntryCard(
          onSubmit: (double amount, String source) async => onSubmit(amount, source),
          onSkip: onSkip,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('hands over a parsed amount and source', (WidgetTester tester) async {
    double? amount;
    String? source;
    await _pump(
      tester,
      onSubmit: (double a, String s) {
        amount = a;
        source = s;
      },
      onSkip: () {},
    );

    await tester.enterText(find.byType(TextField).at(0), '62.000');
    await tester.enterText(find.byType(TextField).at(1), 'Freelance iş');
    await tester.pump();
    await tester.tap(find.text('Kaydet ve devam et'));
    await tester.pump();

    expect(amount, 62000);
    expect(source, 'Freelance iş');
  });

  testWidgets('refuses an empty amount under the field, not over the buttons', (
    WidgetTester tester,
  ) async {
    bool submitted = false;
    await _pump(tester, onSubmit: (double a, String s) => submitted = true, onSkip: () {});

    await tester.tap(find.text('Kaydet ve devam et'));
    await tester.pump();

    expect(submitted, isFalse);
    expect(find.text('Bir tutar gir.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Şimdilik geç'), findsOneWidget);
  });

  testWidgets('refuses an unreadable amount', (WidgetTester tester) async {
    bool submitted = false;
    await _pump(tester, onSubmit: (double a, String s) => submitted = true, onSkip: () {});

    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.pump();
    await tester.tap(find.text('Kaydet ve devam et'));
    await tester.pump();

    expect(submitted, isFalse);
    expect(find.text('Geçerli bir tutar gir.'), findsOneWidget);
  });

  testWidgets('refuses a negative amount', (WidgetTester tester) async {
    bool submitted = false;
    await _pump(tester, onSubmit: (double a, String s) => submitted = true, onSkip: () {});

    await tester.enterText(find.byType(TextField).first, '-500');
    await tester.pump();
    await tester.tap(find.text('Kaydet ve devam et'));
    await tester.pump();

    expect(submitted, isFalse);
  });

  testWidgets('typing clears the refusal', (WidgetTester tester) async {
    await _pump(tester, onSubmit: (double a, String s) {}, onSkip: () {});

    await tester.tap(find.text('Kaydet ve devam et'));
    await tester.pump();
    expect(find.text('Bir tutar gir.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.pump();
    expect(find.text('Bir tutar gir.'), findsNothing);
  });

  testWidgets('skipping reports a skip and submits nothing', (WidgetTester tester) async {
    bool skipped = false;
    bool submitted = false;
    await _pump(
      tester,
      onSubmit: (double a, String s) => submitted = true,
      onSkip: () => skipped = true,
    );

    await tester.tap(find.text('Şimdilik geç'));
    await tester.pump();

    expect(skipped, isTrue);
    expect(submitted, isFalse);
  });
}
