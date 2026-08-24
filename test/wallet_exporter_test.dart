import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/data/services/statement_parser.dart';
import 'package:folio_wallet/data/services/wallet_exporter.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';

final List<TransactionRecord> wallet = <TransactionRecord>[
  TransactionRecord(
    id: '1',
    title: 'Starbucks',
    merchant: 'Starbucks',
    category: 'Kahve',
    amount: 230,
    date: DateTime(2026, 8, 18),
    type: TransactionType.expense,
    source: TransactionSource.statement,
    paymentLabel: 'Visa •••• 2048',
  ),
  TransactionRecord(
    id: '2',
    title: 'Maaş',
    merchant: 'Maaş',
    category: 'Maaş',
    amount: 52000,
    date: DateTime(2026, 8, 1),
    type: TransactionType.income,
    source: TransactionSource.manual,
  ),
];

void main() {
  test('the export is semicolon delimited with a BOM for Excel', () {
    final String csv = WalletExporter.toCsv(wallet);

    expect(csv.startsWith('﻿'), isTrue);
    expect(csv, contains('Tarih;Açıklama;Kategori;Tür;Tutar;Ödeme;Not'));
  });

  test('expenses are negative and income positive', () {
    final String csv = WalletExporter.toCsv(wallet);

    expect(csv, contains('18.08.2026;Starbucks;Kahve;Gider;-230,00'));
    expect(csv, contains('01.08.2026;Maaş;Maaş;Gelir;52000,00'));
  });

  test('rows come out newest first', () {
    final List<String> lines = WalletExporter.toCsv(wallet).trim().split('\r\n');

    expect(lines[1], startsWith('18.08.2026'));
    expect(lines[2], startsWith('01.08.2026'));
  });

  test('the file name carries the export date', () {
    expect(WalletExporter.fileName(now: DateTime(2026, 8, 4)), 'folio-2026-08-04.csv');
  });

  test('an exported file can be imported back into Folio', () async {
    final StatementParseResult result = await const StatementParser().parseNamedBytes(
      name: WalletExporter.fileName(),
      bytes: WalletExporter.toCsvBytes(wallet),
    );

    expect(result.isSuccess, isTrue);
    expect(result.transactions, hasLength(2));

    final TransactionRecord expense = result.transactions.first;
    expect(expense.type, TransactionType.expense);
    expect(expense.amount, 230);
    expect(expense.title, 'Starbucks');
    expect(expense.date, DateTime(2026, 8, 18));

    final TransactionRecord income = result.transactions.last;
    expect(income.type, TransactionType.income);
    expect(income.amount, 52000);
    expect(income.date, DateTime(2026, 8, 1));
  });

  test('an empty wallet still produces a header row', () {
    final String csv = WalletExporter.toCsv(const <TransactionRecord>[]);

    expect(csv, contains('Tarih;Açıklama'));
  });
}
