import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/domain/analytics/subscription_detector.dart';
import 'package:folio_wallet/domain/models/subscription_record.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';

final DateTime anchor = DateTime(2026, 8, 24);

TransactionRecord charge(String merchant, double amount, DateTime date) {
  return TransactionRecord(
    id: '$merchant-${date.toIso8601String()}',
    title: merchant,
    merchant: merchant,
    category: 'Abonelik',
    amount: amount,
    date: date,
    type: TransactionType.expense,
    source: TransactionSource.statement,
  );
}

void main() {
  test('a monthly charge of a stable amount is detected', () {
    final List<TransactionRecord> transactions = <TransactionRecord>[
      charge('Netflix', 229, DateTime(2026, 6, 5)),
      charge('Netflix', 229, DateTime(2026, 7, 5)),
      charge('Netflix', 229, DateTime(2026, 8, 5)),
    ];

    final List<SubscriptionRecord> detected =
        SubscriptionDetector.detect(transactions, now: anchor);

    expect(detected, hasLength(1));
    expect(detected.single.merchant, 'Netflix');
    expect(detected.single.monthlyAmount, 229);
    expect(detected.single.nextBillingDate, DateTime(2026, 9, 5));
  });

  test('a small price increase still counts as the same subscription', () {
    final List<TransactionRecord> transactions = <TransactionRecord>[
      charge('Spotify', 99, DateTime(2026, 6, 8)),
      charge('Spotify', 99, DateTime(2026, 7, 8)),
      charge('Spotify', 119, DateTime(2026, 8, 8)),
    ];

    expect(SubscriptionDetector.detect(transactions, now: anchor), hasLength(1));
  });

  test('a frequently visited shop is not a subscription', () {
    final List<TransactionRecord> transactions = <TransactionRecord>[
      charge('Migros', 780, DateTime(2026, 8, 2)),
      charge('Migros', 640, DateTime(2026, 8, 9)),
      charge('Migros', 810, DateTime(2026, 8, 16)),
      charge('Migros', 705, DateTime(2026, 8, 23)),
    ];

    expect(SubscriptionDetector.detect(transactions, now: anchor), isEmpty);
  });

  test('wildly different amounts are not a subscription', () {
    final List<TransactionRecord> transactions = <TransactionRecord>[
      charge('Shell', 400, DateTime(2026, 6, 6)),
      charge('Shell', 1850, DateTime(2026, 7, 6)),
      charge('Shell', 900, DateTime(2026, 8, 6)),
    ];

    expect(SubscriptionDetector.detect(transactions, now: anchor), isEmpty);
  });

  test('a cancelled subscription drops off the list', () {
    final List<TransactionRecord> transactions = <TransactionRecord>[
      charge('Netflix', 229, DateTime(2026, 1, 5)),
      charge('Netflix', 229, DateTime(2026, 2, 5)),
      charge('Netflix', 229, DateTime(2026, 3, 5)),
    ];

    expect(SubscriptionDetector.detect(transactions, now: anchor), isEmpty);
  });

  test('two charges are not enough evidence', () {
    final List<TransactionRecord> transactions = <TransactionRecord>[
      charge('Netflix', 229, DateTime(2026, 7, 5)),
      charge('Netflix', 229, DateTime(2026, 8, 5)),
    ];

    expect(SubscriptionDetector.detect(transactions, now: anchor), isEmpty);
  });
}
