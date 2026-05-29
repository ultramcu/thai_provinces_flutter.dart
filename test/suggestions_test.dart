// Blind tests for `thaiAddressSuggestions` + `ThaiAddressSuggestion.display`,
// written purely from the v0.2.0 contract (issue #1) and the core
// `package:thai_provinces` ground-truth — NOT from the suggestions.dart
// implementation (which is being written concurrently).
//
// Ground-truth facts asserted here were discovered via the public core API:
//   searchSubdistricts('สุเทพ')  -> 1 result: สุเทพ/Suthep, code 500108,
//                                   postcode 50200, district เมืองเชียงใหม่,
//                                   province เชียงใหม่ (code 50)
//   searchSubdistricts('ในเมือง') -> 22 results (broad; used for the limit test)
//   byPostcode(50200)            -> 3 subdistricts (all share postcode 50200)

import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

void main() {
  group('thaiAddressSuggestions — empty / whitespace', () {
    test('empty query returns an empty list', () {
      expect(thaiAddressSuggestions(''), isEmpty);
    });

    test('whitespace-only query returns an empty list', () {
      expect(thaiAddressSuggestions('   '), isEmpty);
    });
  });

  group('thaiAddressSuggestions — name lookup (Thai / English)', () {
    test('Thai prefix "สุเทพ" finds the Chiang Mai สุเทพ subdistrict', () {
      final results = thaiAddressSuggestions('สุเทพ');
      expect(results, isNotEmpty);

      // Find the specific Chiang Mai สุเทพ (subdistrict code 500108).
      final suthep = results
          .where((s) => s.subdistrict.code == 500108)
          .toList();
      expect(
        suthep,
        hasLength(1),
        reason:
            'the Chiang Mai สุเทพ (code 500108) must be present exactly once',
      );

      final s = suthep.single;
      expect(s.subdistrict.nameTh, 'สุเทพ');
      expect(s.district.nameTh, 'เมืองเชียงใหม่');
      expect(s.province.code, 50);
      expect(s.subdistrict.postcode, 50200);
      // The class-level `postcode` getter must delegate to the subdistrict.
      expect(s.postcode, 50200);
    });

    test('English prefix "Suthep" also finds the Chiang Mai สุเทพ', () {
      final results = thaiAddressSuggestions('Suthep');
      expect(results, isNotEmpty);

      final suthep = results.where((s) => s.subdistrict.code == 500108);
      expect(
        suthep,
        hasLength(1),
        reason: 'English-name search must reach the same subdistrict',
      );
      expect(suthep.single.subdistrict.nameEn, 'Suthep');
      expect(suthep.single.province.code, 50);
      expect(suthep.single.postcode, 50200);
    });
  });

  group('thaiAddressSuggestions — postcode lookup', () {
    test('full postcode "50200" returns results all with postcode 50200', () {
      final results = thaiAddressSuggestions('50200');
      expect(results, isNotEmpty);
      for (final s in results) {
        expect(
          s.postcode,
          50200,
          reason: 'every result of an exact-postcode query must use that code',
        );
        expect(s.subdistrict.postcode, 50200);
      }
    });

    test(
      'partial postcode prefix "502" — every postcode starts with "502"',
      () {
        final results = thaiAddressSuggestions('502');
        expect(results, isNotEmpty);
        for (final s in results) {
          expect(
            s.postcode.toString().startsWith('502'),
            isTrue,
            reason:
                'postcode-prefix search must only return matching codes, got '
                '${s.postcode}',
          );
        }
      },
    );
  });

  group('thaiAddressSuggestions — limit & dedup', () {
    test('limit is respected for a broad query', () {
      // 'ในเมือง' occurs in 22 subdistricts across 19 provinces — broad enough
      // that an unbounded result would exceed 5.
      final results = thaiAddressSuggestions('ในเมือง', limit: 5);
      expect(results.length, lessThanOrEqualTo(5));
      // Sanity: the query is genuinely broad, so the limit actually bites.
      final unlimited = thaiAddressSuggestions('ในเมือง', limit: 100);
      expect(
        unlimited.length,
        greaterThan(5),
        reason: 'ในเมือง should yield more than 5 matches when unbounded',
      );
    });

    test('results are deduped by subdistrict code', () {
      // A postcode query and a name query are both plausible sources of dupes
      // if name-match and postcode-match paths are merged naively.
      for (final query in ['ในเมือง', '50200', 'เมือง']) {
        final results = thaiAddressSuggestions(query, limit: 100);
        final codes = results.map((s) => s.subdistrict.code).toList();
        expect(
          codes.toSet().length,
          codes.length,
          reason:
              'duplicate subdistrict code in results for query "$query": '
              '$codes',
        );
      }
    });
  });

  group('ThaiAddressSuggestion.display', () {
    // Use the unambiguous Chiang Mai สุเทพ suggestion as the fixture.
    ThaiAddressSuggestion suthepSuggestion() {
      final results = thaiAddressSuggestions('สุเทพ');
      return results.firstWhere((s) => s.subdistrict.code == 500108);
    }

    test(
      'display(thai) contains Thai sub/district/province names + postcode',
      () {
        final s = suthepSuggestion();
        final text = s.display(ThaiAddressLanguage.thai);
        expect(text, contains('สุเทพ'));
        expect(text, contains('เมืองเชียงใหม่'));
        expect(text, contains('เชียงใหม่'));
        expect(text, contains('50200'));
      },
    );

    test('display(english) contains English names + postcode', () {
      final s = suthepSuggestion();
      final text = s.display(ThaiAddressLanguage.english);
      expect(text, contains(s.subdistrict.nameEn)); // 'Suthep'
      expect(text, contains(s.district.nameEn));
      expect(text, contains(s.province.nameEn));
      expect(text, contains('50200'));
      // English display must not leak the Thai subdistrict name.
      expect(text, isNot(contains('สุเทพ')));
    });
  });
}
