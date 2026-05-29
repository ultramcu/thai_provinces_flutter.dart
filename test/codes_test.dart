// Blind tests (written from the v0.2.0 spec only, not the implementation) for
// the integer-code APIs added in this milestone:
//
//   * ThaiAddressSelection.fromCodes({provinceCode, districtCode,
//     subdistrictCode}) — build a selection from DOPA geocodes, deriving any
//     missing parents from the child code.
//   * (int?,int?,int?) ThaiAddressSelection.toCodes() — the inverse.
//   * ThaiAddressController.setFromCodes({...}) — controller mirror of fromCodes.
//   * ThaiAddressController.setPostcode(int) — fill as much of the hierarchy as a
//     postal code unambiguously allows.
//
// Ground-truth expected values are computed from the public core API
// (package:thai_provinces) so the assertions defend against a plausible-but-
// wrong implementation rather than restating one.
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

void main() {
  // สุเทพ / Suthep: a known, stable fixture.
  //   subdistrict 500108 -> district 5001 (เมืองเชียงใหม่) -> province 50
  //   (เชียงใหม่), postcode 50200.
  const suthepCode = 500108;
  const chiangMaiMueangCode = 5001;
  const chiangMaiCode = 50;

  final suthep = subdistrictByCode(suthepCode)!;
  final chiangMaiMueang = districtByCode(chiangMaiMueangCode)!;
  final chiangMai = provinceByCode(chiangMaiCode)!;

  group('ThaiAddressSelection.fromCodes', () {
    test('subdistrictCode derives district + province (full selection)', () {
      final sel = ThaiAddressSelection.fromCodes(subdistrictCode: suthepCode);

      // Every level must be populated and must be the *correct* core object,
      // not merely non-null.
      expect(sel.subdistrict, equals(suthep));
      expect(sel.district, equals(chiangMaiMueang));
      expect(sel.province, equals(chiangMai));

      // Hierarchy must be internally consistent (defends against deriving the
      // wrong parent, e.g. truncating to the wrong number of digits).
      expect(sel.district!.code, equals(suthep.districtCode));
      expect(sel.province!.code, equals(suthep.districtCode ~/ 100));
      expect(sel.subdistrict!.districtCode, equals(sel.district!.code));

      // A full subdistrict selection is complete and carries the postcode.
      expect(sel.isComplete, isTrue);
      expect(sel.postcode, equals(suthep.postcode)); // 50200
    });

    test('districtCode derives province but leaves subdistrict null', () {
      final sel = ThaiAddressSelection.fromCodes(
        districtCode: chiangMaiMueangCode,
      );

      expect(sel.district, equals(chiangMaiMueang));
      expect(sel.province, equals(chiangMai));
      expect(
        sel.subdistrict,
        isNull,
        reason: 'a district code must not invent a subdistrict',
      );
      expect(
        sel.isComplete,
        isFalse,
        reason: 'no subdistrict => not a complete address',
      );
    });

    test('provinceCode yields province only', () {
      final sel = ThaiAddressSelection.fromCodes(provinceCode: chiangMaiCode);

      expect(sel.province, equals(chiangMai));
      expect(sel.district, isNull);
      expect(sel.subdistrict, isNull);
      expect(sel.isComplete, isFalse);
    });

    test('no codes -> empty selection', () {
      final sel = ThaiAddressSelection.fromCodes();
      expect(sel.province, isNull);
      expect(sel.district, isNull);
      expect(sel.subdistrict, isNull);
      expect(sel, equals(ThaiAddressSelection.empty));
    });

    test('unknown code clears that level (and below)', () {
      // Unknown province.
      final p = ThaiAddressSelection.fromCodes(provinceCode: 99);
      expect(
        p.province,
        isNull,
        reason: 'province 99 does not exist -> null, not a fabricated value',
      );

      // Unknown district: even though 9999 ~/ 100 == 99 is a non-province, the
      // district itself is unknown so it must be null. A naive impl that always
      // derives a province from the truncated code would wrongly set one.
      final d = ThaiAddressSelection.fromCodes(districtCode: 9999);
      expect(d.district, isNull, reason: 'district 9999 does not exist');

      // Unknown subdistrict.
      final s = ThaiAddressSelection.fromCodes(subdistrictCode: 999999);
      expect(
        s.subdistrict,
        isNull,
        reason: 'subdistrict 999999 does not exist',
      );
    });
  });

  group('toCodes', () {
    test('round-trips a full สุเทพ selection', () {
      final original = ThaiAddressSelection.fromCodes(
        subdistrictCode: suthepCode,
      );

      final codes = original.toCodes();
      // Records expose positional fields $1/$2/$3.
      expect(codes.$1, equals(chiangMaiCode));
      expect(codes.$2, equals(chiangMaiMueangCode));
      expect(codes.$3, equals(suthepCode));

      final rebuilt = ThaiAddressSelection.fromCodes(
        provinceCode: codes.$1,
        districtCode: codes.$2,
        subdistrictCode: codes.$3,
      );
      expect(
        rebuilt,
        equals(original),
        reason: 'fromCodes(x.toCodes()) must reproduce x exactly',
      );
    });

    test('round-trips a province-only selection', () {
      final original = ThaiAddressSelection.fromCodes(
        provinceCode: chiangMaiCode,
      );
      final codes = original.toCodes();
      expect(codes.$1, equals(chiangMaiCode));
      expect(
        codes.$2,
        isNull,
        reason: 'no district selected => district code must be null',
      );
      expect(codes.$3, isNull);

      final rebuilt = ThaiAddressSelection.fromCodes(
        provinceCode: codes.$1,
        districtCode: codes.$2,
        subdistrictCode: codes.$3,
      );
      expect(rebuilt, equals(original));
    });

    test('round-trips a district-level selection', () {
      final original = ThaiAddressSelection.fromCodes(
        districtCode: chiangMaiMueangCode,
      );
      final codes = original.toCodes();
      expect(codes.$1, equals(chiangMaiCode));
      expect(codes.$2, equals(chiangMaiMueangCode));
      expect(codes.$3, isNull);

      final rebuilt = ThaiAddressSelection.fromCodes(
        provinceCode: codes.$1,
        districtCode: codes.$2,
        subdistrictCode: codes.$3,
      );
      expect(rebuilt, equals(original));
    });

    test('round-trips the empty selection', () {
      final original = ThaiAddressSelection.empty;
      final codes = original.toCodes();
      expect(codes.$1, isNull);
      expect(codes.$2, isNull);
      expect(codes.$3, isNull);
      final rebuilt = ThaiAddressSelection.fromCodes(
        provinceCode: codes.$1,
        districtCode: codes.$2,
        subdistrictCode: codes.$3,
      );
      expect(rebuilt, equals(original));
    });

    test('round-trips a second full selection in Bangkok', () {
      // A different province (10 / Bangkok) so a round-trip bug that happens to
      // hardcode Chiang Mai would be caught.
      final bkk = provinceByCode(10)!;
      final district = bkk.districts.first;
      final subdistrict = district.subdistricts.first;

      final original = ThaiAddressSelection.fromCodes(
        subdistrictCode: subdistrict.code,
      );
      final codes = original.toCodes();
      expect(codes, equals((10, district.code, subdistrict.code)));

      final rebuilt = ThaiAddressSelection.fromCodes(
        provinceCode: codes.$1,
        districtCode: codes.$2,
        subdistrictCode: codes.$3,
      );
      expect(rebuilt, equals(original));
      expect(rebuilt.isComplete, isTrue);
    });
  });

  group('ThaiAddressController.setFromCodes', () {
    test('mirrors fromCodes for a full subdistrict selection', () {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      controller.setFromCodes(subdistrictCode: suthepCode);

      final expected = ThaiAddressSelection.fromCodes(
        subdistrictCode: suthepCode,
      );
      expect(
        controller.value,
        equals(expected),
        reason: 'setFromCodes must land the same value as fromCodes',
      );
      expect(controller.value.province, equals(chiangMai));
      expect(controller.value.district, equals(chiangMaiMueang));
      expect(controller.value.subdistrict, equals(suthep));
      expect(controller.value.isComplete, isTrue);
      expect(controller.value.postcode, equals(suthep.postcode));
    });

    test('mirrors fromCodes for a province-only selection', () {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      controller.setFromCodes(provinceCode: chiangMaiCode);

      expect(
        controller.value,
        equals(ThaiAddressSelection.fromCodes(provinceCode: chiangMaiCode)),
      );
      expect(controller.value.province, equals(chiangMai));
      expect(controller.value.district, isNull);
      expect(controller.value.subdistrict, isNull);
    });

    test('replaces a prior selection (not merged into it)', () {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      // Start fully populated in Chiang Mai.
      controller.setFromCodes(subdistrictCode: suthepCode);
      expect(controller.value.isComplete, isTrue);

      // Now set a province-only selection: children must be gone, not retained.
      controller.setFromCodes(provinceCode: 10);
      expect(controller.value.province, equals(provinceByCode(10)));
      expect(
        controller.value.district,
        isNull,
        reason: 'setFromCodes must replace, leaving no stale Chiang Mai child',
      );
      expect(controller.value.subdistrict, isNull);
    });
  });

  group('ThaiAddressController.setPostcode', () {
    test(
      'ambiguous postcode 50200 fills province + district, not subdistrict',
      () {
        // 50200 is shared by 3 subdistricts, all in district 5001 / province 50,
        // so the common ancestor (province + district) is unambiguous but the
        // subdistrict is not.
        final controller = ThaiAddressController();
        addTearDown(controller.dispose);

        controller.setPostcode(50200);

        expect(controller.value.province, isNotNull);
        expect(controller.value.province!.code, equals(chiangMaiCode));
        expect(controller.value.district, isNotNull);
        expect(controller.value.district!.code, equals(chiangMaiMueangCode));
        expect(
          controller.value.subdistrict,
          isNull,
          reason: 'ambiguous postcode must NOT pick an arbitrary subdistrict',
        );
        expect(controller.value.isComplete, isFalse);
      },
    );

    test('unique postcode fills the whole hierarchy (isComplete)', () {
      // Discover a 1:1 postcode dynamically rather than hardcoding a guess.
      final unique = _findUniquePostcode();
      final only = byPostcode(unique).single;

      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      controller.setPostcode(unique);

      expect(
        controller.value.subdistrict,
        equals(only),
        reason: 'a unique postcode resolves to exactly its one subdistrict',
      );
      expect(controller.value.district, equals(only.district));
      expect(controller.value.province, equals(only.province));
      expect(controller.value.isComplete, isTrue);
      expect(controller.value.postcode, equals(unique));
    });

    test('unknown postcode clears the selection', () {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      // Pre-populate so we can prove setPostcode actually clears.
      controller.setFromCodes(subdistrictCode: suthepCode);
      expect(controller.value.isComplete, isTrue);

      // 99999 has no subdistricts.
      expect(
        byPostcode(99999),
        isEmpty,
        reason: 'precondition: 99999 is an unknown postcode',
      );
      controller.setPostcode(99999);

      expect(controller.value.province, isNull);
      expect(controller.value.district, isNull);
      expect(controller.value.subdistrict, isNull);
      expect(controller.value.postcode, isNull);
      expect(
        controller.value,
        equals(ThaiAddressSelection.empty),
        reason: 'an unknown postcode must clear, not leave stale Chiang Mai',
      );
    });
  });

  group('setPostcode pins only the levels all matches share', () {
    test('single-district postcode (50200) pins province + district', () {
      final c = ThaiAddressController()..setPostcode(50200);
      expect(c.province?.code, 50);
      expect(c.district?.code, 5001);
      expect(c.subdistrict, isNull); // 3 candidates in one district
    });

    test('multi-district, single-province (10600) pins province only', () {
      // 10600 spans districts 1015/1016/1018, all in province 10.
      final c = ThaiAddressController()..setPostcode(10600);
      expect(c.province?.code, 10);
      expect(
        c.district,
        isNull,
        reason: 'must not pin an arbitrary district when several share 10600',
      );
      expect(c.subdistrict, isNull);
    });

    test(
      'multi-province postcode (13240) pins neither province nor district',
      () {
        // 13240 spans provinces 14 and 16.
        final c = ThaiAddressController()..setPostcode(13240);
        expect(
          c.province,
          isNull,
          reason: 'must not pin an arbitrary province when several share 13240',
        );
        expect(c.district, isNull);
        expect(c.subdistrict, isNull);
      },
    );

    test('no valid subdistrict of an ambiguous postcode is dropped', () {
      // Every candidate must still resolve to a complete, correct selection.
      for (final s in byPostcode(13240)) {
        final sel = ThaiAddressSelection.fromCodes(subdistrictCode: s.code);
        expect(sel.isComplete, isTrue);
        expect(sel.subdistrict?.code, s.code);
        expect(sel.postcode, 13240);
      }
    });
  });
}

/// Returns a postal code used by exactly one subdistrict (a 1:1 postcode),
/// found by scanning the dataset. Fails the test loudly if none exists.
int _findUniquePostcode() {
  final seen = <int>{};
  for (final s in subdistricts()) {
    if (seen.add(s.postcode) && byPostcode(s.postcode).length == 1) {
      return s.postcode;
    }
  }
  fail('expected at least one 1:1 postcode in the dataset');
}
