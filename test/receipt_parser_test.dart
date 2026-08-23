import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/data/services/receipt_analyzer.dart';

void main() {
  test('Turkish receipt text extracts merchant date and total', () {
    const String text = '''
MIGROS TICARET A.S.
TARIH: 18.08.2026 SAAT: 18:42
KDV 123,20
GENEL TOPLAM 1.284,40 TL
KREDI KARTI
''';

    final ReceiptAnalysis result = ReceiptTextParser.parse(text);

    expect(result.merchant, 'Migros');
    expect(result.amount, 1284.40);
    expect(result.date, DateTime(2026, 8, 18));
    expect(result.category, 'Market');
    expect(result.confidence, greaterThan(0.8));
  });

  test('Receipt parser keeps review-safe defaults when OCR is weak', () {
    final ReceiptAnalysis result = ReceiptTextParser.parse('FIS\nKDV');

    expect(result.merchant, 'Bilinmeyen mağaza');
    expect(result.amount, 0);
    expect(result.category, 'Diğer');
  });
}
