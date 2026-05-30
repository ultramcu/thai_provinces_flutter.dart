import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

void main() {
  group('ThaiAddressValidators.required', () {
    test('null -> Thai default message', () {
      final validator = ThaiAddressValidators.required();
      expect(validator(null), 'กรุณาเลือกที่อยู่ให้ครบ');
    });

    test('null -> English message when language is english', () {
      final validator = ThaiAddressValidators.required(
        language: ThaiAddressLanguage.english,
      );
      expect(validator(null), 'Please select a complete address');
    });

    test('incomplete selection -> non-null Thai message', () {
      final validator = ThaiAddressValidators.required();
      final incomplete =
          ThaiAddressSelection.fromCodes(provinceCode: 50);
      final result = validator(incomplete);
      expect(result, isNotNull);
      expect(result, 'กรุณาเลือกที่อยู่ให้ครบ');
    });

    test('complete selection -> null (valid)', () {
      final validator = ThaiAddressValidators.required();
      final complete =
          ThaiAddressSelection.fromCodes(subdistrictCode: 500108);
      expect(validator(complete), isNull);
    });

    test('custom message overrides default', () {
      final validator = ThaiAddressValidators.required(message: 'X');
      expect(validator(null), 'X');
    });
  });
}
