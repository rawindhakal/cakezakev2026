import 'package:customer/commons/models/country_settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gstinRegex = r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$';

  group('BuyerTaxField', () {
    test('parses enabled country spec', () {
      final data = CountrySettingsData.fromJson({
        'buyer_tax_field': {
          'enabled': 1,
          'label': 'GSTIN',
          'regex': gstinRegex,
        },
      });
      final field = data.buyerTaxField!;
      expect(field.enabled, isTrue);
      expect(field.label, 'GSTIN');
      expect(field.regex, gstinRegex);
    });

    test('enabled 0 and missing block both hide the field', () {
      final off = CountrySettingsData.fromJson({
        'buyer_tax_field': {'enabled': 0, 'label': '', 'regex': null},
      });
      expect(off.buyerTaxField!.enabled, isFalse);
      expect(CountrySettingsData.fromJson({}).buyerTaxField, isNull);
    });

    test('empty is always valid', () {
      const f = BuyerTaxField(enabled: true, label: 'GSTIN', regex: gstinRegex);
      expect(f.isValid(''), isTrue);
      expect(f.isValid('   '), isTrue);
    });

    test('validates the server-normalised form (uppercase, no spaces)', () {
      const f = BuyerTaxField(enabled: true, label: 'GSTIN', regex: gstinRegex);
      expect(f.isValid('27AAPFU0939F1ZV'), isTrue);
      expect(f.isValid('27 aapfu 0939 f1zv'), isTrue);
      expect(f.isValid('27AAPFU0939F1Z'), isFalse);
    });

    test('null regex accepts anything', () {
      const f = BuyerTaxField(enabled: true, label: 'VAT Number');
      expect(f.isValid('anything at all'), isTrue);
    });

    test('uncompilable regex does not block the buyer', () {
      const f = BuyerTaxField(enabled: true, label: 'TRN', regex: '([');
      expect(f.isValid('123'), isTrue);
    });
  });
}
