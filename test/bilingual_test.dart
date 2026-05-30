import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

void main() {
  group('ThaiAddressLanguage.bilingual', () {
    test('labelOf(province) renders "Thai (English)"', () {
      final bangkok = provinceByCode(10)!;
      expect(
        ThaiAddressLanguage.bilingual.labelOf(bangkok),
        'กรุงเทพมหานคร (Bangkok)',
      );
    });

    test('labelOfDistrict renders "Thai (English)"', () {
      final mueangChiangMai = districtByCode(5001)!;
      expect(
        ThaiAddressLanguage.bilingual.labelOfDistrict(mueangChiangMai),
        'เมืองเชียงใหม่ (Mueang Chiang Mai)',
      );
    });

    test('labelOfSubdistrict renders "Thai (English)"', () {
      final suthep = subdistrictByCode(500108)!;
      expect(
        ThaiAddressLanguage.bilingual.labelOfSubdistrict(suthep),
        'สุเทพ (Suthep)',
      );
    });
  });

  group('existing languages unchanged', () {
    test('thai.labelOf returns the Thai name only', () {
      final bangkok = provinceByCode(10)!;
      expect(ThaiAddressLanguage.thai.labelOf(bangkok), 'กรุงเทพมหานคร');
    });

    test('english.labelOf returns the English name only', () {
      final bangkok = provinceByCode(10)!;
      expect(ThaiAddressLanguage.english.labelOf(bangkok), 'Bangkok');
    });
  });
}
