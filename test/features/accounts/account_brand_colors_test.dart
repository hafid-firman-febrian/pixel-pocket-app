import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_brand_colors.dart';

void main() {
  test('each brand name maps to its muted color', () {
    expect(brandColorFor('BCA'), '#386694');
    expect(brandColorFor('Dana'), '#4791C2');
    expect(brandColorFor('GoPay'), '#46A6B9');
    expect(brandColorFor('Jago'), '#D8A246');
    expect(brandColorFor('Cash'), '#46915F');
    expect(brandColorFor('Tunai'), '#46915F');
  });

  test('matching ignores case and extra words', () {
    expect(brandColorFor('bca utama'), '#386694');
    expect(brandColorFor('Bank Jago'), '#D8A246');
    expect(brandColorFor('  GOPAY  '), '#46A6B9');
  });

  test('a name without a brand has no color', () {
    expect(brandColorFor('Dompet'), isNull);
    expect(brandColorFor(''), isNull);
  });

  test('the brand palette lists each color once, in brand order', () {
    expect(accountBrandPalette, [
      '#386694',
      '#4791C2',
      '#46A6B9',
      '#D8A246',
      '#46915F',
    ]);
  });
}
