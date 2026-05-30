// Blind tests (written from the Roadmap #7 spec only, NOT the format()
// implementation) for the printable postal-order address string added to
// ThaiAddressSelection:
//
//   String ThaiAddressSelection.format({
//     ThaiAddressLanguage language = ThaiAddressLanguage.thai,
//     bool includePostcode = true,
//   })
//
// Postal order = subdistrict, then district, then province, then postcode.
// Selections are built via the public ThaiAddressSelection.fromCodes(...) so
// the assertions defend against a plausible-but-wrong implementation rather
// than restating one. Expected strings are the exact, hand-verified outputs
// from the spec's CONFIRMED DATA fixtures.
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

void main() {
  group('format() — full selections', () {
    test(
      'Bangkok full (subdistrict 100101) — thai uses แขวง/เขต breadcrumb',
      () {
        final sel = ThaiAddressSelection.fromCodes(subdistrictCode: 100101);
        expect(
          sel.format(),
          'แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร 10200',
        );
      },
    );

    test('Bangkok full (subdistrict 100101) — english', () {
      final sel = ThaiAddressSelection.fromCodes(subdistrictCode: 100101);
      expect(
        sel.format(language: ThaiAddressLanguage.english),
        'Phra Borom Maha Ratchawang, Khet Phra Nakhon, Bangkok 10200',
      );
    });

    test(
      'Chiang Mai full (subdistrict 500108) — thai uses ตำบล/อำเภอ/จังหวัด',
      () {
        final sel = ThaiAddressSelection.fromCodes(subdistrictCode: 500108);
        expect(
          sel.format(),
          'ตำบลสุเทพ อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่ 50200',
        );
      },
    );

    test('Chiang Mai full (subdistrict 500108) — english', () {
      final sel = ThaiAddressSelection.fromCodes(subdistrictCode: 500108);
      expect(
        sel.format(language: ThaiAddressLanguage.english),
        'Suthep, Mueang Chiang Mai, Chiang Mai 50200',
      );
    });
  });

  group('format() — includePostcode:false on a full selection', () {
    test('Bangkok thai ends at province (no trailing postcode)', () {
      final sel = ThaiAddressSelection.fromCodes(subdistrictCode: 100101);
      expect(
        sel.format(includePostcode: false),
        'แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร',
      );
    });

    test('Bangkok english ends at province (no trailing postcode)', () {
      final sel = ThaiAddressSelection.fromCodes(subdistrictCode: 100101);
      expect(
        sel.format(
          language: ThaiAddressLanguage.english,
          includePostcode: false,
        ),
        'Phra Borom Maha Ratchawang, Khet Phra Nakhon, Bangkok',
      );
    });

    test('Chiang Mai thai ends at province (no trailing postcode)', () {
      final sel = ThaiAddressSelection.fromCodes(subdistrictCode: 500108);
      expect(
        sel.format(includePostcode: false),
        'ตำบลสุเทพ อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่',
      );
    });

    test('Chiang Mai english ends at province (no trailing postcode)', () {
      final sel = ThaiAddressSelection.fromCodes(subdistrictCode: 500108);
      expect(
        sel.format(
          language: ThaiAddressLanguage.english,
          includePostcode: false,
        ),
        'Suthep, Mueang Chiang Mai, Chiang Mai',
      );
    });
  });

  group('format() — partial selections', () {
    test('province-only Chiang Mai — thai', () {
      final sel = ThaiAddressSelection.fromCodes(provinceCode: 50);
      expect(sel.format(), 'จังหวัดเชียงใหม่');
    });

    test('province-only Bangkok — thai (verbatim, no จังหวัด prefix)', () {
      final sel = ThaiAddressSelection.fromCodes(provinceCode: 10);
      expect(sel.format(), 'กรุงเทพมหานคร');
    });

    test('province-only Chiang Mai — english', () {
      final sel = ThaiAddressSelection.fromCodes(provinceCode: 50);
      expect(sel.format(language: ThaiAddressLanguage.english), 'Chiang Mai');
    });

    test('province-only Bangkok — english', () {
      final sel = ThaiAddressSelection.fromCodes(provinceCode: 10);
      expect(sel.format(language: ThaiAddressLanguage.english), 'Bangkok');
    });

    test('province + district (no subdistrict) — thai, no postcode', () {
      final sel = ThaiAddressSelection.fromCodes(districtCode: 5001);
      expect(sel.format(), 'อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่');
    });

    test('province + district (no subdistrict) — english, no postcode', () {
      final sel = ThaiAddressSelection.fromCodes(districtCode: 5001);
      expect(
        sel.format(language: ThaiAddressLanguage.english),
        'Mueang Chiang Mai, Chiang Mai',
      );
    });

    test(
      'Bangkok province + district (no subdistrict) — thai, no postcode',
      () {
        final sel = ThaiAddressSelection.fromCodes(districtCode: 1001);
        expect(sel.format(), 'เขตพระนคร กรุงเทพมหานคร');
      },
    );

    test(
      'Bangkok province + district (no subdistrict) — english, no postcode',
      () {
        final sel = ThaiAddressSelection.fromCodes(districtCode: 1001);
        expect(
          sel.format(language: ThaiAddressLanguage.english),
          'Khet Phra Nakhon, Bangkok',
        );
      },
    );
  });

  group('format() — empty selection', () {
    test('empty -> empty string (thai)', () {
      expect(ThaiAddressSelection.empty.format(), '');
    });

    test('empty -> empty string (english)', () {
      expect(
        ThaiAddressSelection.empty.format(
          language: ThaiAddressLanguage.english,
        ),
        '',
      );
    });
  });
}
