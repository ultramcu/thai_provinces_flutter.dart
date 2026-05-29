// BLIND TEST (written from spec only — postcode_field.dart impl NOT read).
//
// Exercises ThaiPostcodeField: typing a postcode resolves the address via the
// core `byPostcode`, an AMBIGUOUS postcode (several subdistricts) leaves the
// subdistrict unset and shows an inline chooser, picking from the chooser
// completes the selection (and fires onChanged), a UNIQUE postcode completes
// straight away with no chooser, and junk input never crashes.
//
// Ground-truth expected values are computed from package:thai_provinces at
// runtime (no hardcoded guesses for the "unique" case) so a wrong widget impl
// fails these for the right reason.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The barrel re-exports the core API (byPostcode/subdistricts/Subdistrict/...).
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

/// The well-known AMBIGUOUS postcode: 50200 maps to 3 subdistricts in district
/// 5001 (เมืองเชียงใหม่) / province 50 (เชียงใหม่).
const int kAmbiguousPostcode = 50200;

/// Pumps a [ThaiPostcodeField] with [controller] inside a minimal app, and
/// returns the list of [ThaiAddressSelection]s seen via onChanged.
Future<List<ThaiAddressSelection>> _pumpField(
  WidgetTester tester, {
  required ThaiAddressController controller,
  bool showSubdistrictChooser = true,
  ThaiAddressLanguage language = ThaiAddressLanguage.thai,
}) async {
  final changes = <ThaiAddressSelection>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ThaiPostcodeField(
          controller: controller,
          language: language,
          showSubdistrictChooser: showSubdistrictChooser,
          onChanged: changes.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return changes;
}

/// Types [text] into the single text field of the pumped postcode widget.
Future<void> _enterText(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

void main() {
  // ---- Ground-truth from the embedded dataset --------------------------
  final ambiguous = byPostcode(kAmbiguousPostcode);

  // Discover a genuinely UNIQUE (1:1) postcode by scanning — never hardcode.
  late final int uniquePostcode;
  late final Subdistrict uniqueSub;
  {
    final counts = <int, int>{};
    for (final s in subdistricts()) {
      counts[s.postcode] = (counts[s.postcode] ?? 0) + 1;
    }
    Subdistrict? pick;
    int? pickPc;
    for (final entry in counts.entries) {
      if (entry.value == 1) {
        final list = byPostcode(entry.key);
        if (list.length == 1) {
          pick = list.first;
          pickPc = entry.key;
          break;
        }
      }
    }
    uniqueSub = pick!;
    uniquePostcode = pickPc!;
  }

  group(
    'ThaiPostcodeField — ground-truth sanity (core API, not the widget)',
    () {
      test('50200 is ambiguous with one shared province/district', () {
        // Guards the test premise: if the dataset ever changes so 50200 is no
        // longer ambiguous, the ambiguity tests below would be meaningless.
        expect(
          ambiguous.length,
          greaterThan(1),
          reason: '50200 must map to several subdistricts',
        );
        expect(ambiguous.map((s) => s.province?.code).toSet(), {50});
        expect(ambiguous.map((s) => s.districtCode).toSet(), {5001});
      });

      test('a unique postcode was found by scanning', () {
        expect(byPostcode(uniquePostcode).length, 1);
      });
    },
  );

  group('ThaiPostcodeField — ambiguous postcode (50200)', () {
    testWidgets(
      'resolves province + district, leaves subdistrict null, shows a chooser',
      (tester) async {
        final controller = ThaiAddressController();
        await _pumpField(tester, controller: controller);

        await _enterText(tester, '50200');

        // Province + district resolved from the shared parents...
        expect(
          controller.province?.code,
          50,
          reason: 'ambiguous postcode should still resolve the province',
        );
        expect(
          controller.district?.code,
          5001,
          reason: 'ambiguous postcode should still resolve the district',
        );
        // ...but the subdistrict stays unset for the user to disambiguate.
        expect(
          controller.subdistrict,
          isNull,
          reason: 'ambiguous postcode must NOT auto-pick a subdistrict',
        );
        expect(controller.value.isComplete, isFalse);

        // Open the chooser so its options render (a closed DropdownButton
        // paints no item text), then it must surface EVERY candidate by name.
        await tester.tap(
          find.byKey(const Key('thaiAddress.postcodeSubdistrict')),
        );
        await tester.pumpAndSettle();
        for (final s in ambiguous) {
          expect(
            find.text(s.nameTh),
            findsWidgets,
            reason: 'chooser must offer candidate ${s.nameTh}',
          );
        }
      },
    );

    testWidgets('picking a subdistrict from the chooser completes the selection '
        'and fires onChanged', (tester) async {
      final controller = ThaiAddressController();
      final changes = await _pumpField(tester, controller: controller);

      await _enterText(tester, '50200');
      expect(controller.subdistrict, isNull); // precondition

      // Choose สุเทพ / Suthep (500108) — one of the three candidates.
      final target = ambiguous.firstWhere((s) => s.code == 500108);
      final before = changes.length;
      // Open the chooser, then pick สุเทพ from the menu overlay.
      await tester.tap(
        find.byKey(const Key('thaiAddress.postcodeSubdistrict')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(target.nameTh).last);
      await tester.pumpAndSettle();

      // Selection is now complete and points at exactly the chosen subdistrict.
      expect(controller.subdistrict?.code, 500108);
      expect(controller.province?.code, 50);
      expect(controller.district?.code, 5001);
      expect(controller.value.isComplete, isTrue);
      expect(controller.value.postcode, kAmbiguousPostcode);

      // onChanged fired again with the completed selection.
      expect(
        changes.length,
        greaterThan(before),
        reason: 'choosing a subdistrict must notify onChanged',
      );
      expect(changes.last.subdistrict?.code, 500108);

      // Chooser is dismissed once the pick resolves the ambiguity:
      // the other (now non-selected) candidate names are gone.
      final other = ambiguous.firstWhere((s) => s.code != 500108);
      expect(
        find.text(other.nameTh),
        findsNothing,
        reason: 'chooser should disappear after a pick',
      );
    });
  });

  group('ThaiPostcodeField — multi-district postcode (10600)', () {
    // 10600 maps to subdistricts across districts 1015/1016/1018 (one province,
    // 10). setPostcode can pin only the province, so the chooser must still
    // appear even though no district is pinned, and a pick must resolve the
    // full address (committing via fromCodes, not setSubdistrict).
    testWidgets('shows the chooser with district unpinned, pick completes', (
      tester,
    ) async {
      final candidates = byPostcode(10600);
      // Premise guard: genuinely multi-district.
      expect(
        candidates.map((s) => s.districtCode).toSet().length,
        greaterThan(1),
      );

      final controller = ThaiAddressController();
      final changes = await _pumpField(tester, controller: controller);
      await _enterText(tester, '10600');

      expect(controller.province?.code, 10);
      expect(
        controller.district,
        isNull,
        reason: 'a multi-district postcode must not pin an arbitrary district',
      );

      // The chooser still appears (it does not require a pinned district).
      await tester.tap(
        find.byKey(const Key('thaiAddress.postcodeSubdistrict')),
      );
      await tester.pumpAndSettle();

      final target = candidates.first;
      await tester.tap(find.text(target.nameTh).last);
      await tester.pumpAndSettle();

      expect(controller.value.isComplete, isTrue);
      expect(controller.subdistrict?.code, target.code);
      expect(controller.district?.code, target.districtCode);
      expect(changes.last.subdistrict?.code, target.code);
    });
  });

  group('ThaiPostcodeField — multi-province postcode (13240)', () {
    // 13240 spans provinces 14 and 16, so setPostcode pins NOTHING. The chooser
    // must still appear (driven by the active postcode, not a pinned level) and
    // a pick must resolve the full address.
    testWidgets('shows the chooser with nothing pinned, pick completes', (
      tester,
    ) async {
      final candidates = byPostcode(13240);
      // Premise guard: genuinely multi-province.
      expect(
        candidates.map((s) => s.districtCode ~/ 100).toSet().length,
        greaterThan(1),
      );

      final controller = ThaiAddressController();
      final changes = await _pumpField(tester, controller: controller);
      await _enterText(tester, '13240');

      expect(controller.province, isNull);
      expect(controller.district, isNull);
      expect(controller.subdistrict, isNull);

      // The chooser appears even though no province/district is pinned.
      final chooser = find.byKey(const Key('thaiAddress.postcodeSubdistrict'));
      expect(chooser, findsOneWidget);
      await tester.tap(chooser);
      await tester.pumpAndSettle();

      final target = candidates.first;
      await tester.tap(find.text(target.nameTh).last);
      await tester.pumpAndSettle();

      expect(controller.value.isComplete, isTrue);
      expect(controller.subdistrict?.code, target.code);
      expect(controller.province?.code, target.districtCode ~/ 100);
      expect(changes.last.subdistrict?.code, target.code);
    });
  });

  group('ThaiPostcodeField — unique postcode', () {
    testWidgets('completes the selection with no chooser', (tester) async {
      final controller = ThaiAddressController();
      await _pumpField(tester, controller: controller);

      await _enterText(tester, uniquePostcode.toString());

      // A 1:1 postcode resolves all three levels immediately.
      expect(
        controller.value.isComplete,
        isTrue,
        reason: 'a unique postcode must auto-complete the whole address',
      );
      expect(controller.subdistrict?.code, uniqueSub.code);
      expect(controller.subdistrict?.postcode, uniquePostcode);
      expect(controller.province?.code, uniqueSub.province?.code);
      expect(controller.district?.code, uniqueSub.districtCode);

      // No disambiguation chooser is shown for a unique postcode. The only
      // other candidate with the *ambiguous* postcode must NOT be present.
      final ambiguousOther = byPostcode(kAmbiguousPostcode).first;
      expect(find.text(ambiguousOther.nameTh), findsNothing);
    });

    testWidgets('fires onChanged with the completed selection', (tester) async {
      final controller = ThaiAddressController();
      final changes = await _pumpField(tester, controller: controller);

      await _enterText(tester, uniquePostcode.toString());

      expect(changes, isNotEmpty, reason: 'unique postcode must notify');
      expect(changes.last.isComplete, isTrue);
      expect(changes.last.subdistrict?.code, uniqueSub.code);
    });
  });

  group('ThaiPostcodeField — invalid / unknown input does not crash', () {
    testWidgets('too-few digits leaves selection empty and shows no chooser', (
      tester,
    ) async {
      final controller = ThaiAddressController();
      await _pumpField(tester, controller: controller);

      await _enterText(tester, '502'); // not 5 digits

      expect(
        controller.value.isEmpty,
        isTrue,
        reason: 'partial input must not resolve an address',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('non-digit text does not crash', (tester) async {
      final controller = ThaiAddressController();
      await _pumpField(tester, controller: controller);

      await _enterText(tester, 'abcde');

      expect(controller.value.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unknown 5-digit postcode clears / leaves selection empty', (
      tester,
    ) async {
      // 99999 is not a real Thai postcode.
      expect(byPostcode(99999), isEmpty); // ground-truth premise

      final controller = ThaiAddressController();
      await _pumpField(tester, controller: controller);

      await _enterText(tester, '99999');

      expect(controller.value.isComplete, isFalse);
      expect(controller.subdistrict, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clearing the field after a unique pick resets the selection', (
      tester,
    ) async {
      final controller = ThaiAddressController();
      await _pumpField(tester, controller: controller);

      await _enterText(tester, uniquePostcode.toString());
      expect(controller.value.isComplete, isTrue);

      await _enterText(tester, '');
      expect(
        controller.value.isEmpty,
        isTrue,
        reason: 'emptying the field should clear the resolved address',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
