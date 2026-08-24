import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/data/services/pdf_statement_reader.dart';
import 'package:folio_wallet/data/services/statement_parser.dart';

/// Reports what the reader sees inside a statement that will not open.
///
/// Run it against your own file:
///
///   flutter test test/pdf_diagnose_test.dart --dart-define=pdf=C:/yol/ekstre.pdf
///
/// Every digit in the output is replaced with `#`, so account numbers, amounts
/// and dates never appear. What stays readable is the layout: how many words a
/// line holds and what the column headings are called.
const String pdfPath = String.fromEnvironment('pdf');
const int lineLimit = int.fromEnvironment('lines', defaultValue: 30);
const int lineOffset = int.fromEnvironment('from');

void main() {
  test('describe the statement layout', () async {
    if (pdfPath.isEmpty) {
      // ignore: avoid_print
      print(
        'Bir dosya verilmedi. Kullanım:\n'
        '  flutter test test/pdf_diagnose_test.dart --dart-define=pdf=C:/yol/ekstre.pdf',
      );
      return;
    }

    final File file = File(pdfPath);
    expect(file.existsSync(), isTrue, reason: 'Dosya bulunamadı: $pdfPath');
    final List<int> bytes = await file.readAsBytes();

    // ignore: avoid_print
    print('\n===== FOLIO PDF TEŞHİS =====\n');
    // ignore: avoid_print
    print(PdfStatementReader.describe(bytes, lineLimit: lineLimit, lineOffset: lineOffset));

    final StatementParseResult result =
        await const StatementParser().parseNamedBytes(name: 'ekstre.pdf', bytes: bytes);
    // ignore: avoid_print
    print('Ayrıştırma sonucu: ${result.status.name}');
    // ignore: avoid_print
    print('Mesaj: ${result.message}');
    // ignore: avoid_print
    print('Bulunan işlem sayısı: ${result.transactions.length}');
    for (final String warning in result.warnings) {
      // ignore: avoid_print
      print('Uyarı: $warning');
    }
    // ignore: avoid_print
    print('\n===== BİTTİ =====\n');
  });
}
