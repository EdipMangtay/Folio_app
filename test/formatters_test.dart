import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/utils/formatters.dart';

void main() {
  group('Formatters.parseMoneyInput', () {
    test('parses Turkish and international money formats', () {
      expect(Formatters.parseMoneyInput('1.284,40 ₺'), 1284.40);
      expect(Formatters.parseMoneyInput('1284,40'), 1284.40);
      expect(Formatters.parseMoneyInput('1284.40'), 1284.40);
      expect(Formatters.parseMoneyInput('12.450.840,42'), 12450840.42);
      expect(Formatters.parseMoneyInput('999.999'), 999999);
    });

    test('rejects empty values', () {
      expect(Formatters.parseMoneyInput(''), isNull);
      expect(Formatters.parseMoneyInput('₺'), isNull);
    });
  });
}
