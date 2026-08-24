import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/data/services/pdf_statement_reader.dart';
import 'package:folio_wallet/data/services/statement_parser.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const StatementParser parser = StatementParser();

/// The built-in PDF fonts use WinAnsi encoding, which has no dotless ı and no
/// İ — a fixture drawn with one would silently lose the very characters these
/// tests are about. Manrope is already bundled with the app, so it doubles as
/// a Turkish-capable font for the fixtures.
PdfFont turkishFont(double size) =>
    PdfTrueTypeFont(File('assets/fonts/Manrope-Regular.ttf').readAsBytesSync(), size);

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
  final PdfFont font = turkishFont(10);
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

/// Draws a payment receipt (`dekont`) the way a bank does: label column on the
/// left, a small Hesap/Borç/Alacak ledger, then the description.
///
/// [inlineDescription] switches between the two layouts seen in the wild — the
/// description next to its label, or on the line below it.
void drawReceipt(
  PdfGraphics graphics,
  PdfFont font, {
  required double y,
  required String date,
  required String ownAccount,
  required String debit,
  required String credit,
  required String counterAccount,
  required String description,
  required bool inlineDescription,
}) {
  void at(double x, double top, String text) =>
      graphics.drawString(text, font, bounds: Rect.fromLTWH(x, top, 200, 14));

  at(58, y, 'AKBANK');
  at(58, y + 14, 'Tarih');
  at(174, y + 14, date);
  at(58, y + 28, 'Borçlu Ad');
  at(58, y + 42, 'AD SOYAD');

  at(58, y + 56, 'Hesap');
  at(174, y + 56, 'Borç');
  at(316, y + 56, 'Alacak');

  at(58, y + 70, ownAccount);
  at(174, y + 70, debit);
  at(316, y + 70, credit);

  at(58, y + 84, counterAccount);
  at(174, y + 84, credit);
  at(316, y + 84, debit);

  at(58, y + 98, 'TOPLAM');
  at(174, y + 98, debit == '0,00' ? credit : debit);
  at(316, y + 98, debit == '0,00' ? credit : debit);

  at(58, y + 112, 'Yazı İle');
  if (inlineDescription) {
    at(58, y + 126, 'Açıklama');
    at(246, y + 126, description);
  } else {
    at(58, y + 126, 'Açıklama');
    at(246, y + 140, description);
  }
}

List<int> buildReceiptsPdf() {
  final PdfDocument document = PdfDocument();
  final PdfGraphics graphics = document.pages.add().graphics;
  final PdfFont font = turkishFont(9);

  drawReceipt(
    graphics,
    font,
    y: 20,
    date: '18.08.2026',
    ownAccount: 'MEVDUAT TL',
    debit: '46,00',
    credit: '0,00',
    counterAccount: 'BKM POS SATIS TL',
    description: 'STARBUCKS BESIKTAS TEMASSIZ',
    inlineDescription: true,
  );
  drawReceipt(
    graphics,
    font,
    y: 200,
    date: '20.08.2026',
    ownAccount: 'MEVDUAT TL',
    debit: '0,00',
    credit: '1.250,00',
    counterAccount: 'MUHASEBE TL',
    description: 'TRENDYOL.COM IADE',
    inlineDescription: false,
  );

  final List<int> bytes = document.saveSync();
  document.dispose();
  return bytes;
}

void main() {
  _diagnosticPrivacy();

  test('a column-based PDF statement is read like a spreadsheet', () async {
    final List<int> bytes = buildStatementPdf(
      titleBlock: <String>[
        'AKBANK T.A.S.',
        'Hesap Özeti',
        'Dönem: 01.08.2026 - 31.08.2026',
      ],
      headers: <String>['İşlem Tarihi', 'Açıklama', 'Tutar'],
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
      headers: <String>['Tarih', 'Açıklama', 'Tutar', 'Bakiye'],
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
      headers: <String>['Tarih', 'Açıklama', 'Borç', 'Alacak'],
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
      headers: <String>['Tarih', 'Açıklama', 'Tutar'],
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

  test('a summary line above the table is not mistaken for the header', () async {
    // "Donem Ici Islem Tutari" reads like a header — it carries both a
    // description word and a money word — but it is prose, not a table. The
    // reader has to score it against the real header and discard it.
    final List<int> bytes = buildStatementPdf(
      titleBlock: <String>[
        'AKBANK T.A.S.',
        'Dönem İçi İşlem Tutarı Toplamı 1.514,40',
        'Kullanılabilir Limit 24.000,00',
      ],
      headers: <String>['Tarih', 'Açıklama', 'Tutar'],
      rows: <List<String>>[
        <String>['18.08.2026', 'STARBUCKS', '-230,00'],
        <String>['19.08.2026', 'MIGROS', '-1.284,40'],
      ],
    );

    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'ekstre.pdf', bytes: bytes);

    expect(result.isSuccess, isTrue);
    expect(result.transactions, hasLength(2));
    expect(result.transactions.first.title, 'Starbucks');
    expect(result.transactions.first.amount, 230);
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
      headers: <String>['Tarih', 'Açıklama', 'Tutar'],
      rows: <List<String>>[
        <String>['18.08.2026', 'STARBUCKS', '-230,00'],
      ],
    );

    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'ekstre.csv', bytes: bytes);

    expect(result.isSuccess, isTrue);
    expect(result.transactions.single.title, 'Starbucks');
  });

  test('a batch of payment receipts is read as individual transactions', () async {
    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'Dekont_20260824.pdf', bytes: buildReceiptsPdf());

    expect(result.isSuccess, isTrue);
    expect(result.transactions, hasLength(2));

    // The customer's own account is debited, so money left: an expense.
    final TransactionRecord outgoing = result.transactions
        .firstWhere((TransactionRecord t) => t.type == TransactionType.expense);
    expect(outgoing.amount, 46);
    expect(outgoing.title, 'Starbucks');
    expect(outgoing.date, DateTime(2026, 8, 18));

    // Credited instead, so money arrived: an income.
    final TransactionRecord incoming = result.transactions
        .firstWhere((TransactionRecord t) => t.type == TransactionType.income);
    expect(incoming.amount, 1250);
    expect(incoming.date, DateTime(2026, 8, 20));
  });

  test('a receipt description does not run into the next receipt', () async {
    final StatementParseResult result =
        await parser.parseNamedBytes(name: 'Dekont.pdf', bytes: buildReceiptsPdf());

    expect(result.isSuccess, isTrue);
    for (final TransactionRecord transaction in result.transactions) {
      expect(transaction.title.toUpperCase(), isNot(contains('AKBANK')));
      expect(transaction.title.toUpperCase(), isNot(contains('TARIH')));
    }
  });

  test('a PDF without any statement table fails instead of inventing rows', () async {
    final PdfDocument document = PdfDocument();
    document.pages.add().graphics.drawString(
          'Sayin musterimiz, kampanyamizdan haberdar olmak icin subelerimize bekleriz.',
          turkishFont(12),
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

void _diagnosticPrivacy() {
  test('the diagnostic report hides personal details', () {
    final String report = PdfStatementReader.describe(buildReceiptsPdf(), lineLimit: 40);

    // The fixture draws a "Borçlu Ad" label followed by a name on the next line.
    expect(report, isNot(contains('AD SOYAD')));
    expect(report, contains('[kişisel bilgi gizlendi]'));
    // No digit survives in the masked text itself. The line index and word
    // count that prefix each row are the reader's own numbering, not content.
    final List<String> maskedTexts = report
        .split('\n')
        .where((String line) => RegExp(r'^\d+ \| \d+ kelime \| ').hasMatch(line))
        .map((String line) => line.split('| ').last)
        .toList();
    expect(maskedTexts, isNotEmpty);
    for (final String text in maskedTexts) {
      expect(RegExp(r'\d').hasMatch(text), isFalse, reason: 'maskelenmemiş rakam: $text');
    }
  });
}
