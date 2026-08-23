import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/data/services/merchant_normalizer.dart';

void main() {
  test('merchant aliases normalize cleanly', () {
    expect(MerchantNormalizer.normalize('STARBUCKS 00123 IST'), 'Starbucks');
    expect(MerchantNormalizer.normalize('MIGROS TICARET A.S.'), 'Migros');
    expect(MerchantNormalizer.normalize('APPLE.COM/BILL'), 'Apple');
  });

  test('category inference covers common merchants', () {
    expect(MerchantNormalizer.categoryFor('Starbucks'), 'Kahve');
    expect(MerchantNormalizer.categoryFor('Migros'), 'Market');
    expect(MerchantNormalizer.categoryFor('Netflix'), 'Abonelik');
  });
}
