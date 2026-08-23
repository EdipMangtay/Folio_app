import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/data/services/statement_parser.dart';

void main() {
  test('CSV statement creates reviewable transactions', () async {
    const String csv = '''Tarih,Açıklama,Tutar
18.08.2026,STARBUCKS BESIKTAS,230.00
19.08.2026,MIGROS TICARET,1284.40
''';
    final List<int> bytes = utf8.encode(csv);

    final StatementParseResult result = await const StatementParser().parseNamedBytes(
      name: 'ekstre.csv',
      bytes: bytes,
    );

    expect(result.isDemoFallback, isFalse);
    expect(result.transactions, hasLength(2));
    expect(result.transactions.first.title, 'Starbucks');
    expect(result.transactions.first.category, 'Kahve');
    expect(result.transactions.last.title, 'Migros');
    expect(result.transactions.last.amount, 1284.40);
  });
}
