import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/domain/analytics/analytics_engine.dart';
import 'package:folio_wallet/presentation/widgets/spending_chart.dart';

/// A realistic statement month: money moves on 9 of 31 days, one large rent
/// payment, everything else zero. This shape is what a smoothed line destroys.
const Map<int, double> _spendByDay = <int, double>{
  2: 4200,
  5: 320,
  6: 180,
  11: 1450,
  12: 260,
  18: 12000,
  19: 540,
  25: 890,
  28: 310,
};

List<DailySpendPoint> _july() => <DailySpendPoint>[
      for (int day = 1; day <= 31; day++)
        DailySpendPoint(DateTime(2026, 7, day), _spendByDay[day] ?? 0),
    ];

Future<BarChartData> _pumpChart(WidgetTester tester, List<DailySpendPoint> points) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: SpendingChart(points: points),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<BarChart>(find.byType(BarChart)).data;
}

double _plotted(BarChartData data, int dayIndex) {
  final BarChartGroupData group =
      data.barGroups.firstWhere((BarChartGroupData g) => g.x == dayIndex);
  return group.barRods.first.toY;
}

void main() {
  testWidgets('plots exactly the amount it was given for every day', (WidgetTester tester) async {
    final List<DailySpendPoint> points = _july();
    final BarChartData data = await _pumpChart(tester, points);

    expect(data.barGroups.length, points.length);
    for (int i = 0; i < points.length; i++) {
      expect(
        _plotted(data, i),
        points[i].amount,
        reason: '${i + 1} Temmuz için çizilen değer gerçek harcamadan farklı',
      );
    }
  });

  testWidgets('draws nothing on a day with no spending', (WidgetTester tester) async {
    // The old smoothed line put 933 ₺ on the 1st and 2.727 ₺ on the 17th,
    // days on which no money moved at all.
    final BarChartData data = await _pumpChart(tester, _july());

    for (final int day in <int>[1, 16, 17, 31]) {
      expect(
        _plotted(data, day - 1),
        0,
        reason: '$day Temmuz boş bir gün, grafikte yükseklik olmamalı',
      );
    }
  });

  testWidgets('the vertical scale reaches the real peak day', (WidgetTester tester) async {
    // The old chart scaled the axis to 12.000 ₺ but never drew above 4.120 ₺,
    // so the visible line sat at a third of the height.
    final BarChartData data = await _pumpChart(tester, _july());

    final double tallest = data.barGroups
        .map((BarChartGroupData g) => g.barRods.first.toY)
        .reduce((double a, double b) => a > b ? a : b);

    expect(tallest, 12000);
    expect(data.maxY, greaterThanOrEqualTo(12000));
    // The peak should fill most of the plot rather than hugging the floor.
    expect(tallest / data.maxY, greaterThan(0.6));
  });

  testWidgets('says so when the period holds no spending at all', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SpendingChart(
            points: <DailySpendPoint>[
              for (int day = 1; day <= 31; day++) DailySpendPoint(DateTime(2026, 7, day), 0),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsNothing);
    expect(find.textContaining('harcama yok'), findsOneWidget);
  });

  testWidgets('handles an empty period without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SpendingChart(points: <DailySpendPoint>[])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('the vertical axis formats every tick the same way', (WidgetTester tester) async {
    // The axis ticks are all multiples of one step, so they must share one
    // format. `5.0k` beside `10k` reads as two different scales, and the dot
    // contradicts the comma the rest of the app uses for decimals.
    await _pumpChart(tester, _july());

    expect(find.text('5k'), findsOneWidget);
    expect(find.text('10k'), findsOneWidget);
    expect(find.text('5.0k'), findsNothing);
  });

  testWidgets('a small month labels its axis in plain lira, not fractions of k', (
    WidgetTester tester,
  ) async {
    final List<DailySpendPoint> small = <DailySpendPoint>[
      for (int day = 1; day <= 30; day++)
        DailySpendPoint(DateTime(2026, 6, day), day == 9 ? 1450 : 0),
    ];
    await _pumpChart(tester, small);

    // `0,8k` for 750 lira is unreadable; the number itself is short enough.
    expect(find.textContaining('k'), findsNothing);
  });

  testWidgets('the date labels along the bottom never overlap each other', (
    WidgetTester tester,
  ) async {
    // Three labels centred on their day slot will collide at the edges if the
    // text is wider than the slot. The test font is wider than the bundled
    // Manrope, so passing here is the conservative case.
    await _pumpChart(tester, _july());

    final Iterable<Element> labels = find
        .descendant(of: find.byType(BarChart), matching: find.textContaining('Tem'))
        .evaluate();
    expect(labels.length, greaterThanOrEqualTo(2));

    final List<Rect> rects = labels
        .map((Element e) {
          final RenderBox box = e.renderObject! as RenderBox;
          return box.localToGlobal(Offset.zero) & box.size;
        })
        .toList()
      ..sort((Rect a, Rect b) => a.left.compareTo(b.left));

    for (int i = 1; i < rects.length; i++) {
      expect(
        rects[i].left,
        greaterThanOrEqualTo(rects[i - 1].right),
        reason: 'tarih etiketleri üst üste biniyor: ${rects[i - 1]} / ${rects[i]}',
      );
    }
  });
}
