import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/data/services/statement_parser.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const StatementParser parser = StatementParser();

/// Draws a statement the way a bank PDF lays one out: a title block, a header
/// row and right-aligned amounts in fixed columns.
List<int> buildStatementPdf({
  required List<String> headers,
  required List<List<String>> rows,
  List<String> titleBlock = const <String>[],
  List<double> columnX = const <double>[],
  List<String> footer = const <String>[],
}) {
  final PdfDocument document = PdfDocument();
  final PdfPage page = document.pages.add();
  final PdfGraphics graphics = page.graphics;
  final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 10);
  final List<double> xs = columnX.isNotEmpty
      ? columnX
      : <double>[for (int i = 0; i < headers.length; i++) 20 + i * 120];

  double y = 20;
  for (final String line in titleBlock) {
    graphics.drawString(line, font, bounds: Rect.fromLTWH(20, y, 500, 16));
    y += 18;
  }

  // A single-cell row is a whole statement line, so it needs the full width
  // instead of a column-sized box that would wrap it.
  double cellWidth(int cellCount) => cellCount == 1 ? 500 : 118;

  y += 10;
  for (int i = 0; i < headers.length; i++) {
    graphics.drawString(
      headers[i],
      font,
      bounds: Rect.fromLTWH(xs[i], y, cellWidth(headers.length), 16),
    );
  }
  y += 20;

  for (final List<String> row in rows) {
    for (int i = 0; i < row.length; i++) {
      graphics.drawString(
        row[i],
        font,
        bounds: Rect.fromLTWH(xs[i], y, cellWidth(row.length), 16),
      );
    }
    y += 18;
  }

  y += 10;
  for (final String line in footer) {
    graphics.drawString(line, font, bounds: Rect.fromLTWH(20, y, 500, 16));
    y += 18;
  }

  final List<int> bytes = document.saveSync();
  document.dispose();
  return bytes;
}

void main() {
  test('a column-based PDF statement is read like a spreadsheet', () async {
    final List<int> bytes = buildStatementPdf(
      titleBlock: <String>[
        'AKBANK T.A.S.',
        'Hesap Ozeti',
        'Donem: 01.08.2026 - 31.08.2026',
      ],
      headers: <String>['Islem Tarihi', 'Aciklama', 'Tutar'],
      rows: <List<String>>[
        <String>['18.08.2026', 'STARBUCKS BESIKTAS', '-230,00'],
        <String>['19.08.2026', 'MIGROS TICARET AS', '-1.284,40'],
        <String>['01.08.2026', 'MAAS ODEMESI', '52.000,00'],
      ],
    );

    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'ekstre.pdf', bytes: bytes);

    expect(result.isSuccess, isTrue);
    expect(result.transactions, hasLength(3));

    expect(result.transactions[0].title, 'Starbucks');
    expect(result.transactions[0].amount, 230);
    expect(result.transactions[0].type, TransactionType.expense);
    expect(result.transactions[0].date, DateTime(2026, 8, 18));

    expect(result.transactions[2].type, TransactionType.income);
    expect(result.transactions[2].amount, 52000);
    expect(result.transactions[2].category, 'Maaş');
  });

  test('a balance column does not become the amount', () async {
    final List<int> bytes = buildStatementPdf(
      headers: <String>['Tarih', 'Aciklama', 'Tutar', 'Bakiye'],
      columnX: const <double>[20, 110, 300, 400],
      rows: <List<String>>[
        <String>['18.08.2026', 'STARBUCKS', '-230,00', '12.400,00'],
        <String>['19.08.2026', 'SHELL', '-1.850,00', '10.550,00'],
      ],
    );

    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'ekstre.pdf', bytes: bytes);

    expect(result.isSuccess, isTrue);
    expect(result.transactions.map((TransactionRecord t) => t.amount), <double>[230, 1850]);
  });

  test('debit and credit columns split expense from income', () async {
    final List<int> bytes = buildStatementPdf(
      headers: <String>['Tarih', 'Aciklama', 'Borc', 'Alacak'],
      columnX: const <double>[20, 110, 300, 400],
      rows: <List<String>>[
        <String>['18.08.2026', 'STARBUCKS', '230,00', ''],
        <String>['01.08.2026', 'MAAS ODEMESI', '', '52.000,00'],
      ],
    );

    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'ekstre.pdf', bytes: bytes);

    expect(result.isSuccess, isTrue);
    expect(result.transactions.first.type, TransactionType.expense);
    expect(result.transactions.last.type, TransactionType.income);
    expect(result.transactions.last.amount, 52000);
  });

  test('footer totals are not imported as transactions', () async {
    final List<int> bytes = buildStatementPdf(
      headers: <String>['Tarih', 'Aciklama', 'Tutar'],
      rows: <List<String>>[
        <String>['18.08.2026', 'STARBUCKS', '-230,00'],
      ],
      footer: <String>['TOPLAM 230,00'],
    );

    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'ekstre.pdf', bytes: bytes);

    expect(result.isSuccess, isTrue);
    expect(result.transactions, hasLength(1));
  });

  test('a headerless statement tells the amount from the running balance', () async {
    // No header row at all, and every line carries both an amount and the
    // balance after it. The reader has to work out which column is which.
    final List<int> bytes = buildStatementPdf(
      headers: <String>['18.08.2026 STARBUCKS -230,00 12.400,00'],
      rows: <List<String>>[
        <String>['19.08.2026 SHELL -1.850,00 10.550,00'],
        <String>['20.08.2026 MIGROS -420,00 10.130,00'],
        <String>['21.08.2026 GETIR -180,00 9.950,00'],
      ],
    );

    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'ekstre.pdf', bytes: bytes);

    expect(result.isSuccess, isTrue);
    expect(
      result.transactions.map((TransactionRecord t) => t.amount).toList()..sort(),
      <double>[180, 230, 420, 1850],
    );
  });

  test('a headerless card statement with one amount per line still reads', () async {
    final List<int> bytes = buildStatementPdf(
      headers: <String>['18.08.2026 STARBUCKS 230,00'],
      rows: <List<String>>[
        <String>['19.08.2026 TRENDYOL 1.160,00'],
      ],
    );

    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'ekstre.pdf', bytes: bytes);

    expect(result.isSuccess, isTrue);
    expect(result.transactions, hasLength(2));
    expect(result.transactions.every((TransactionRecord t) => t.isExpense), isTrue);
    expect(result.warnings, isNotEmpty);
  });

  test('a PDF saved under a .csv name is still read as a PDF', () async {
    final List<int> bytes = buildStatementPdf(
      headers: <String>['Tarih', 'Aciklama', 'Tutar'],
      rows: <List<String>>[
        <String>['18.08.2026', 'STARBUCKS', '-230,00'],
      ],
    );

    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'ekstre.csv', bytes: bytes);

    expect(result.isSuccess, isTrue);
    expect(result.transactions.single.title, 'Starbucks');
  });

  test('a PDF without any statement table fails instead of inventing rows', () async {
    final PdfDocument document = PdfDocument();
    document.pages.add().graphics.drawString(
          'Sayin musterimiz, kampanyamizdan haberdar olmak icin subelerimize bekleriz.',
          PdfStandardFont(PdfFontFamily.helvetica, 12),
          bounds: const Rect.fromLTWH(20, 20, 500, 40),
        );
    final List<int> bytes = document.saveSync();
    document.dispose();

    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'reklam.pdf', bytes: bytes);

    expect(result.isSuccess, isFalse);
    expect(result.transactions, isEmpty);
  });
}
