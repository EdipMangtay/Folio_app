import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/data/services/statement_parser.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';

const StatementParser parser = StatementParser();

Future<StatementParseResult> parseCsv(String content, {String name = 'ekstre.csv'}) {
  return parser.parseNamedBytes(name: name, bytes: utf8.encode(content));
}

/// Encodes text the way a Windows-1254 (Turkish) bank export would.
List<int> encodeCp1254(String text) {
  return text.runes
      .map(
        (int rune) => switch (rune) {
          0x00C7 => 0xC7, 0x00E7 => 0xE7, // Ç ç
          0x011E => 0xD0, 0x011F => 0xF0, // Ğ ğ
          0x0130 => 0xDD, 0x0131 => 0xFD, // İ ı
          0x00D6 => 0xD6, 0x00F6 => 0xF6, // Ö ö
          0x015E => 0xDE, 0x015F => 0xFE, // Ş ş
          0x00DC => 0xDC, 0x00FC => 0xFC, // Ü ü
          _ => rune,
        },
      )
      .toList(growable: false);
}

void main() {
  group('column mapping', () {
    test('İşlem Tarihi is not mistaken for the description column', () async {
      final StatementParseResult result = await parseCsv(
        'İşlem Tarihi;Açıklama;Tutar\r\n'
        '18.08.2026;STARBUCKS BESIKTAS;-230,00\r\n'
        '19.08.2026;MIGROS TICARET AS;-1.284,40\r\n',
      );

      expect(result.isSuccess, isTrue);
      expect(result.transactions.first.title, 'Starbucks');
      expect(result.transactions.first.category, 'Kahve');
      expect(result.transactions.last.title, 'Migros');
      expect(result.transactions.last.amount, 1284.40);
    });

    test('balance column is never used as the amount', () async {
      final StatementParseResult result = await parseCsv(
        'Tarih;Açıklama;Tutar;Bakiye\r\n'
        '18.08.2026;STARBUCKS;-230,00;12.400,00\r\n'
        '19.08.2026;MAAS ODEMESI;52.000,00;64.400,00\r\n',
      );

      expect(result.isSuccess, isTrue);
      expect(result.transactions.first.amount, 230);
      expect(result.transactions.last.amount, 52000);
    });

    test('reads a header that sits below a bank title block', () async {
      final StatementParseResult result = await parseCsv(
        'ÖRNEK BANKASI A.Ş.\r\n'
        'Hesap Özeti\r\n'
        'Dönem: 01.08.2026 - 31.08.2026\r\n'
        '\r\n'
        'Tarih,Açıklama,Borç,Alacak\r\n'
        '18.08.2026,STARBUCKS,230.00,\r\n',
      );

      expect(result.isSuccess, isTrue);
      expect(result.transactions, hasLength(1));
    });
  });

  group('expense and income separation', () {
    test('debit and credit columns map to expense and income', () async {
      final StatementParseResult result = await parseCsv(
        'Tarih;Açıklama;Borç;Alacak;Bakiye\r\n'
        '18.08.2026;STARBUCKS;230,00;;12.400,00\r\n'
        '01.08.2026;MAAS ODEMESI;;52.000,00;64.400,00\r\n',
      );

      expect(result.isSuccess, isTrue);
      expect(result.transactions.first.type, TransactionType.expense);
      expect(result.transactions.last.type, TransactionType.income);
      expect(result.transactions.last.amount, 52000);
      expect(result.transactions.last.category, 'Maaş');
    });

    test('a signed amount column keeps the sign as the direction', () async {
      final StatementParseResult result = await parseCsv(
        'Tarih,Açıklama,Tutar\r\n'
        '18.08.2026,STARBUCKS,-230.00\r\n'
        '01.08.2026,MAAS ODEMESI,52000.00\r\n',
      );

      expect(result.isSuccess, isTrue);
      expect(result.transactions.first.type, TransactionType.expense);
      expect(result.transactions.last.type, TransactionType.income);
      expect(result.warnings, isEmpty);
    });

    test('an unsigned card statement stays expense-only and warns', () async {
      final StatementParseResult result = await parseCsv(
        'Tarih,Açıklama,Tutar\r\n'
        '18.08.2026,STARBUCKS,230.00\r\n'
        '19.08.2026,TRENDYOL,1160.00\r\n',
      );

      expect(result.isSuccess, isTrue);
      expect(
        result.transactions.every((TransactionRecord item) => item.isExpense),
        isTrue,
      );
      expect(result.warnings, isNotEmpty);
    });

    test('trailing minus and parentheses are read as negative', () async {
      final StatementParseResult result = await parseCsv(
        'Tarih,Açıklama,Tutar\r\n'
        '18.08.2026,STARBUCKS,"230,00-"\r\n'
        '19.08.2026,SHELL,"(1.850,00)"\r\n'
        '01.08.2026,MAAS,52000\r\n',
      );

      expect(result.isSuccess, isTrue);
      expect(result.transactions[0].type, TransactionType.expense);
      expect(result.transactions[0].amount, 230);
      expect(result.transactions[1].type, TransactionType.expense);
      expect(result.transactions[1].amount, 1850);
      expect(result.transactions[2].type, TransactionType.income);
    });
  });

  group('file handling', () {
    test('Windows-1254 encoded statements are decoded, not mangled', () async {
      final StatementParseResult result = await parser.parseNamedBytes(
        name: 'ekstre.csv',
        bytes: encodeCp1254(
          'Tarih;Açıklama;Tutar\r\n'
          '18.08.2026;STARBUCKS ŞİŞLİ;-230,00\r\n',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.transactions.single.title, 'Starbucks');
    });

    test('a UTF-8 BOM does not break the first header', () async {
      final StatementParseResult result = await parser.parseNamedBytes(
        name: 'ekstre.csv',
        bytes: <int>[0xEF, 0xBB, 0xBF, ...utf8.encode('Tarih,Açıklama,Tutar\r\n18.08.2026,STARBUCKS,230.00\r\n')],
      );

      expect(result.isSuccess, isTrue);
      expect(result.transactions, hasLength(1));
    });

    test('summary and balance rows are skipped', () async {
      final StatementParseResult result = await parseCsv(
        'Tarih;Açıklama;Tutar\r\n'
        '18.08.2026;STARBUCKS;-230,00\r\n'
        ';TOPLAM;-230,00\r\n'
        ';DEVREDEN BAKİYE;12.400,00\r\n',
      );

      expect(result.isSuccess, isTrue);
      expect(result.transactions, hasLength(1));
      expect(result.warnings.any((String w) => w.contains('atlandı')), isTrue);
    });
  });

  group('failures never fabricate transactions', () {
    test('a corrupt PDF fails with a PDF-specific explanation', () async {
      final StatementParseResult result = await parser.parseNamedBytes(
        name: 'ekstre.pdf',
        bytes: <int>[37, 80, 68, 70],
      );

      expect(result.isSuccess, isFalse);
      expect(result.status, StatementParseStatus.unreadableFile);
      expect(result.message, contains('PDF'));
      expect(result.transactions, isEmpty);
    });

    test('a PDF is recognised by its content even when the name says otherwise', () async {
      final StatementParseResult result = await parser.parseNamedBytes(
        name: 'ekstre.csv',
        bytes: <int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37],
      );

      // Routed to the PDF reader despite the .csv name, and it fails as a PDF.
      expect(result.status, StatementParseStatus.unreadableFile);
      expect(result.message, contains('PDF'));
      expect(result.transactions, isEmpty);
    });

    test('a binary file is rejected before parsing', () async {
      final StatementParseResult result = await parser.parseNamedBytes(
        name: 'foto',
        bytes: <int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46],
      );

      expect(result.status, StatementParseStatus.unsupportedFormat);
      expect(result.transactions, isEmpty);
    });

    test('a statement saved without any extension still parses', () async {
      final StatementParseResult result = await parser.parseNamedBytes(
        name: 'ekstre',
        bytes: utf8.encode('Tarih;Açıklama;Tutar\r\n18.08.2026;STARBUCKS;-230,00\r\n'),
      );

      expect(result.isSuccess, isTrue);
      expect(result.transactions.single.title, 'Starbucks');
    });

    test('unrecognised columns produce a failure, not sample data', () async {
      final StatementParseResult result = await parseCsv('Kolon1,Kolon2\r\na,b\r\n');

      expect(result.isSuccess, isFalse);
      expect(result.status, StatementParseStatus.columnsNotRecognised);
      expect(result.transactions, isEmpty);
    });

    test('an empty file produces a failure', () async {
      final StatementParseResult result = await parser.parseNamedBytes(
        name: 'ekstre.csv',
        bytes: const <int>[],
      );

      expect(result.isSuccess, isFalse);
      expect(result.transactions, isEmpty);
    });
  });
}
