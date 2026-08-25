import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/domain/analytics/analytics_engine.dart';
import 'package:folio_wallet/domain/analytics/month_scope.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';

TransactionRecord _tx({
  required String id,
  required double amount,
  required DateTime date,
  TransactionType type = TransactionType.expense,
  String category = 'Market',
}) {
  return TransactionRecord(
    id: id,
    title: 'Kayit $id',
    merchant: 'Kayit $id',
    category: category,
    amount: amount,
    date: date,
    type: type,
    source: TransactionSource.statement,
  );
}

void main() {
  group('MonthScope.monthOf', () {
    test('normalises any date to the first instant of its month', () {
      expect(MonthScope.monthOf(DateTime(2026, 7, 18, 14, 33)), DateTime(2026, 7));
    });
  });

  group('MonthScope.anchorFor', () {
    final DateTime now = DateTime(2026, 8, 25, 9, 15);

    test('anchors the live month to now so the chart stops today', () {
      expect(MonthScope.anchorFor(DateTime(2026, 8), now: now), now);
    });

    test('anchors a past month to its last day so the chart covers it fully', () {
      expect(MonthScope.anchorFor(DateTime(2026, 7), now: now), DateTime(2026, 7, 31));
    });

    test('handles short and leap months', () {
      expect(MonthScope.anchorFor(DateTime(2026, 2), now: now), DateTime(2026, 2, 28));
      expect(MonthScope.anchorFor(DateTime(2024, 2), now: now), DateTime(2024, 2, 29));
      expect(MonthScope.anchorFor(DateTime(2025, 4), now: now), DateTime(2025, 4, 30));
    });

    test('anchors a future month to its last day', () {
      expect(MonthScope.anchorFor(DateTime(2026, 9), now: now), DateTime(2026, 9, 30));
    });
  });

  group('MonthScope.availableMonths', () {
    final DateTime now = DateTime(2026, 8, 25);

    test('returns only the live month when there are no transactions', () {
      expect(
        MonthScope.availableMonths(const <TransactionRecord>[], now: now),
        <DateTime>[DateTime(2026, 8)],
      );
    });

    test('spans every month from the oldest transaction to the live month', () {
      final List<DateTime> months = MonthScope.availableMonths(
        <TransactionRecord>[
          _tx(id: '1', amount: 100, date: DateTime(2026, 5, 4)),
          _tx(id: '2', amount: 100, date: DateTime(2026, 7, 20)),
        ],
        now: now,
      );
      expect(months, <DateTime>[
        DateTime(2026, 5),
        DateTime(2026, 6),
        DateTime(2026, 7),
        DateTime(2026, 8),
      ]);
    });

    test('crosses a year boundary in order', () {
      final List<DateTime> months = MonthScope.availableMonths(
        <TransactionRecord>[_tx(id: '1', amount: 100, date: DateTime(2025, 11, 9))],
        now: DateTime(2026, 1, 15),
      );
      expect(months, <DateTime>[
        DateTime(2025, 11),
        DateTime(2025, 12),
        DateTime(2026, 1),
      ]);
    });

    test('extends past the live month when a transaction is dated ahead', () {
      final List<DateTime> months = MonthScope.availableMonths(
        <TransactionRecord>[_tx(id: '1', amount: 100, date: DateTime(2026, 10, 2))],
        now: now,
      );
      expect(months.first, DateTime(2026, 8));
      expect(months.last, DateTime(2026, 10));
    });
  });

  group('regression: imported statement from a past period', () {
    // The bug: a statement covering July was stored and listed under
    // Transactions, but the Dashboard and Analytics pages reported zero income
    // and zero expense because they were hard-scoped to the live month.
    final DateTime now = DateTime(2026, 8, 25);
    final List<TransactionRecord> imported = <TransactionRecord>[
      _tx(id: '1', amount: 62000, date: DateTime(2026, 7, 15), type: TransactionType.income, category: 'Maaş'),
      _tx(id: '2', amount: 4200, date: DateTime(2026, 7, 18)),
      _tx(id: '3', amount: 1300, date: DateTime(2026, 7, 29)),
    ];

    test('the live month still reports nothing, which is correct', () {
      final WalletAnalytics live = AnalyticsEngine.compute(
        imported,
        now: MonthScope.anchorFor(DateTime(2026, 8), now: now),
      );
      expect(live.monthIncome, 0);
      expect(live.monthExpense, 0);
    });

    test('selecting the statement month surfaces its income and expense', () {
      final WalletAnalytics july = AnalyticsEngine.compute(
        imported,
        now: MonthScope.anchorFor(DateTime(2026, 7), now: now),
      );
      expect(july.monthIncome, 62000);
      expect(july.monthExpense, 5500);
      expect(july.savings, 56500);
      expect(july.categoryTotals['Market'], 5500);
    });

    test('the daily series covers the whole selected month, not just part of it', () {
      final WalletAnalytics july = AnalyticsEngine.compute(
        imported,
        now: MonthScope.anchorFor(DateTime(2026, 7), now: now),
      );
      expect(july.dailySeries.length, 31);
      expect(july.dailySeries.last.date, DateTime(2026, 7, 31));
    });
  });

  group('MonthScope.dominantMonth', () {
    test('returns null for an empty batch', () {
      expect(MonthScope.dominantMonth(const <TransactionRecord>[]), isNull);
    });

    test('returns the month holding the most rows', () {
      final DateTime? month = MonthScope.dominantMonth(<TransactionRecord>[
        _tx(id: '1', amount: 10, date: DateTime(2026, 7, 3)),
        _tx(id: '2', amount: 10, date: DateTime(2026, 7, 19)),
        _tx(id: '3', amount: 10, date: DateTime(2026, 7, 28)),
        _tx(id: '4', amount: 10, date: DateTime(2026, 8, 2)),
      ]);
      expect(month, DateTime(2026, 7));
    });

    test('breaks a tie towards the most recent month', () {
      final DateTime? month = MonthScope.dominantMonth(<TransactionRecord>[
        _tx(id: '1', amount: 10, date: DateTime(2026, 6, 3)),
        _tx(id: '2', amount: 10, date: DateTime(2026, 7, 19)),
      ]);
      expect(month, DateTime(2026, 7));
    });

    test('a statement spanning a period boundary lands on its bulk', () {
      // Card statements run mid-month to mid-month, so a few rows spill over.
      final List<TransactionRecord> statement = <TransactionRecord>[
        for (int day = 16; day <= 30; day++)
          _tx(id: 'jun-\$day', amount: 10, date: DateTime(2026, 6, day)),
        for (int day = 1; day <= 5; day++)
          _tx(id: 'jul-\$day', amount: 10, date: DateTime(2026, 7, day)),
      ];
      expect(MonthScope.dominantMonth(statement), DateTime(2026, 6));
    });
  });

  group('MonthScope.canStep', () {
    final List<DateTime> months = <DateTime>[
      DateTime(2026, 6),
      DateTime(2026, 7),
      DateTime(2026, 8),
    ];

    test('stops at both ends of the range', () {
      expect(MonthScope.canStep(DateTime(2026, 6), -1, months), isFalse);
      expect(MonthScope.canStep(DateTime(2026, 8), 1, months), isFalse);
    });

    test('moves freely inside the range', () {
      expect(MonthScope.canStep(DateTime(2026, 7), -1, months), isTrue);
      expect(MonthScope.canStep(DateTime(2026, 7), 1, months), isTrue);
    });

    test('a month that fell outside the range can step back into it', () {
      // The July transactions were deleted, so the range shrank to August
      // alone while July was still selected. The user must not be stranded.
      final List<DateTime> shrunk = <DateTime>[DateTime(2026, 8)];
      expect(MonthScope.canStep(DateTime(2026, 7), 1, shrunk), isTrue);
      expect(MonthScope.canStep(DateTime(2026, 7), -1, shrunk), isFalse);
    });

    test('never steps when there is no range at all', () {
      expect(MonthScope.canStep(DateTime(2026, 8), 1, const <DateTime>[]), isFalse);
    });
  });

  group('MonthScope.initialMonth', () {
    final DateTime now = DateTime(2026, 8, 25);

    test('falls back to the live month when the wallet is empty', () {
      expect(
        MonthScope.initialMonth(const <TransactionRecord>[], now: now),
        DateTime(2026, 8),
      );
    });

    test('stays on the live month when it already holds transactions', () {
      final DateTime month = MonthScope.initialMonth(
        <TransactionRecord>[
          _tx(id: '1', amount: 100, date: DateTime(2026, 7, 4)),
          _tx(id: '2', amount: 100, date: DateTime(2026, 8, 3)),
        ],
        now: now,
      );
      expect(month, DateTime(2026, 8));
    });

    test('lands on the newest month holding data when the live month is empty', () {
      // The reported case: a statement covering July, imported in August.
      final DateTime month = MonthScope.initialMonth(
        <TransactionRecord>[
          _tx(id: '1', amount: 100, date: DateTime(2026, 5, 4)),
          _tx(id: '2', amount: 100, date: DateTime(2026, 7, 20)),
        ],
        now: now,
      );
      expect(month, DateTime(2026, 7));
    });

    test('prefers a closed month over a future-dated one', () {
      final DateTime month = MonthScope.initialMonth(
        <TransactionRecord>[
          _tx(id: '1', amount: 100, date: DateTime(2026, 7, 20)),
          _tx(id: '2', amount: 100, date: DateTime(2026, 11, 2)),
        ],
        now: now,
      );
      expect(month, DateTime(2026, 7));
    });

    test('uses the earliest future month when every row is ahead of today', () {
      final DateTime month = MonthScope.initialMonth(
        <TransactionRecord>[
          _tx(id: '1', amount: 100, date: DateTime(2026, 10, 2)),
          _tx(id: '2', amount: 100, date: DateTime(2026, 12, 9)),
        ],
        now: now,
      );
      expect(month, DateTime(2026, 10));
    });

    test('the month it picks is always inside the selectable range', () {
      final List<TransactionRecord> items = <TransactionRecord>[
        _tx(id: '1', amount: 100, date: DateTime(2025, 12, 30)),
      ];
      final DateTime picked = MonthScope.initialMonth(items, now: now);
      final List<DateTime> months = MonthScope.availableMonths(items, now: now);
      expect(months, contains(picked));
    });
  });
}
