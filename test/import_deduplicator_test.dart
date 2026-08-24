import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/data/services/import_deduplicator.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';

TransactionRecord record({
  required String id,
  String merchant = 'Starbucks',
  double amount = 230,
  int day = 18,
  TransactionType type = TransactionType.expense,
  TransactionSource source = TransactionSource.statement,
}) {
  return TransactionRecord(
    id: id,
    title: merchant,
    merchant: merchant,
    category: 'Kahve',
    amount: amount,
    date: DateTime(2026, 8, day),
    type: type,
    source: source,
  );
}

void main() {
  test('re-importing the same statement adds nothing', () {
    final List<TransactionRecord> existing = <TransactionRecord>[
      record(id: 'a'),
      record(id: 'b', merchant: 'Migros', amount: 1284.4, day: 19),
    ];
    final List<TransactionRecord> incoming = <TransactionRecord>[
      record(id: 'c'),
      record(id: 'd', merchant: 'Migros', amount: 1284.4, day: 19),
    ];

    final ImportSplit split = ImportDeduplicator.split(incoming: incoming, existing: existing);

    expect(split.fresh, isEmpty);
    expect(split.duplicates, hasLength(2));
  });

  test('a genuine second identical charge is still imported', () {
    final List<TransactionRecord> existing = <TransactionRecord>[record(id: 'a')];
    final List<TransactionRecord> incoming = <TransactionRecord>[
      record(id: 'b'),
      record(id: 'c'),
    ];

    final ImportSplit split = ImportDeduplicator.split(incoming: incoming, existing: existing);

    expect(split.fresh, hasLength(1));
    expect(split.duplicates, hasLength(1));
  });

  test('a manually entered charge does not block the bank row', () {
    final List<TransactionRecord> existing = <TransactionRecord>[
      record(id: 'a', source: TransactionSource.manual),
    ];

    final ImportSplit split = ImportDeduplicator.split(
      incoming: <TransactionRecord>[record(id: 'b')],
      existing: existing,
    );

    expect(split.fresh, hasLength(1));
    expect(split.duplicates, isEmpty);
  });

  test('new rows in a longer statement are kept', () {
    final List<TransactionRecord> existing = <TransactionRecord>[record(id: 'a')];
    final List<TransactionRecord> incoming = <TransactionRecord>[
      record(id: 'b'),
      record(id: 'c', merchant: 'Shell', amount: 1850, day: 20),
    ];

    final ImportSplit split = ImportDeduplicator.split(incoming: incoming, existing: existing);

    expect(split.fresh.single.merchant, 'Shell');
    expect(split.duplicates, hasLength(1));
  });
}
