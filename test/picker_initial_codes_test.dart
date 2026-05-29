// BLIND TEST (Dev3 1:1) — written from the shared SPEC only, without reading
// lib/src/picker.dart. It exercises the new `initialCodes` constructor param of
// ThaiAddressPicker: a `(int? provinceCode, int? districtCode,
// int? subdistrictCode)?` record that seeds the picker on its first frame.
//
// Ground-truth (verified against package:thai_provinces):
//   subdistrict สุเทพ/Suthep 500108 -> district เมืองเชียงใหม่ 5001 ->
//   province เชียงใหม่ 50, postcode 50200 (50200 is AMBIGUOUS: 3 subdistricts).
//
// These MUST fail on the current stubs (initialCodes not wired; fromCodes/
// setFromCodes throw UnimplementedError) — that's the fail-before.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const provinceKey = Key('thaiAddress.province');
const districtKey = Key('thaiAddress.district');
const subdistrictKey = Key('thaiAddress.subdistrict');
const postcodeKey = Key('thaiAddress.postcode');

DropdownButtonFormField<T> _dropdown<T>(WidgetTester tester, Key key) =>
    tester.widget<DropdownButtonFormField<T>>(find.byKey(key));

/// The currently selected value rendered by a keyed [DropdownButtonFormField].
/// [DropdownButtonFormField] does not expose `value` directly, so read it off
/// the inner [DropdownButton].
T? _dropdownValue<T>(WidgetTester tester, Key key) {
  final button = tester.widget<DropdownButton<T>>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byType(DropdownButton<T>),
    ),
  );
  return button.value;
}

String _postcodeText(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(postcodeKey)).controller!.text;

void main() {
  // Ground-truth fixtures derived from the live dataset.
  final suthep = subdistrictByCode(500108)!; // code 500108, postcode 50200
  final chiangMaiCity = districtByCode(5001)!; // เมืองเชียงใหม่
  final chiangMai = provinceByCode(50)!; // เชียงใหม่

  group('ThaiAddressPicker(initialCodes:) with no controller', () {
    testWidgets(
      'full codes (50, 5001, 500108) seed a complete selection on first frame',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const ThaiAddressPicker(initialCodes: (50, 5001, 500108))),
        );
        // Allow any post-first-frame seeding callback to run.
        await tester.pump();

        // The rendered dropdown values must reflect the seeded selection.
        expect(
          _dropdownValue<Province>(tester, provinceKey),
          equals(chiangMai),
          reason: 'province dropdown should show เชียงใหม่ (50)',
        );
        expect(
          _dropdownValue<District>(tester, districtKey),
          equals(chiangMaiCity),
          reason: 'district dropdown should show เมืองเชียงใหม่ (5001)',
        );
        expect(
          _dropdownValue<Subdistrict>(tester, subdistrictKey),
          equals(suthep),
          reason: 'subdistrict dropdown should show สุเทพ (500108)',
        );

        // Child dropdowns must be ENABLED (a wrong impl might seed the value
        // yet leave children disabled because no province was "chosen").
        expect(
          _dropdown<District>(tester, districtKey).onChanged,
          isNotNull,
          reason: 'district enabled once a province is seeded',
        );
        expect(
          _dropdown<Subdistrict>(tester, subdistrictKey).onChanged,
          isNotNull,
          reason: 'subdistrict enabled once a district is seeded',
        );

        // Postcode field reflects the seeded subdistrict's postcode (50200).
        expect(
          _postcodeText(tester),
          equals('50200'),
          reason: 'postcode field filled from seeded subdistrict',
        );
      },
    );

    testWidgets('province-only codes (50, null, null) seed the province only', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ThaiAddressPicker(initialCodes: (50, null, null))),
      );
      await tester.pump();

      expect(
        _dropdownValue<Province>(tester, provinceKey),
        equals(chiangMai),
        reason: 'province seeded',
      );
      // District/subdistrict must be UNSET — a wrong impl that auto-derives a
      // child would fail here.
      expect(
        _dropdownValue<District>(tester, districtKey),
        isNull,
        reason: 'no district seeded when districtCode is null',
      );
      expect(
        _dropdownValue<Subdistrict>(tester, subdistrictKey),
        isNull,
        reason: 'no subdistrict seeded when subdistrictCode is null',
      );

      // District enabled (province present), subdistrict disabled (no
      // district). This pins the cascade-enable behaviour.
      expect(
        _dropdown<District>(tester, districtKey).onChanged,
        isNotNull,
        reason: 'district enabled because a province is seeded',
      );
      expect(
        _dropdown<Subdistrict>(tester, subdistrictKey).onChanged,
        isNull,
        reason: 'subdistrict disabled because no district is seeded',
      );

      // No subdistrict => no postcode.
      expect(
        _postcodeText(tester),
        isEmpty,
        reason: 'postcode empty without a subdistrict',
      );
    });
  });

  group('ThaiAddressPicker(initialCodes:) with a supplied controller', () {
    testWidgets(
      'full codes drive controller.value to a complete selection (codes match)',
      (tester) async {
        final controller = ThaiAddressController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            ThaiAddressPicker(
              controller: controller,
              initialCodes: const (50, 5001, 500108),
            ),
          ),
        );
        await tester.pump();

        expect(
          controller.value.isComplete,
          isTrue,
          reason: 'controller seeded to a complete selection by initialCodes',
        );
        // Read back via the codes round-trip on the held selection.
        expect(
          controller.value.toCodes(),
          equals((50, 5001, 500108)),
          reason: 'seeded codes round-trip through the controller value',
        );
        expect(
          controller.value.postcode,
          equals(50200),
          reason: 'postcode derived from the seeded subdistrict',
        );
        // Concrete objects (defends against a partial/wrong derivation).
        expect(controller.province, equals(chiangMai));
        expect(controller.district, equals(chiangMaiCity));
        expect(controller.subdistrict, equals(suthep));
      },
    );

    testWidgets(
      'a controller with a pre-existing non-empty selection is NOT clobbered',
      (tester) async {
        // Seed the controller up-front with a DIFFERENT (Bangkok) selection.
        final bangkok = provinceByCode(10)!;
        final controller = ThaiAddressController(
          initial: ThaiAddressSelection(province: bangkok),
        );
        addTearDown(controller.dispose);

        expect(
          controller.value.isEmpty,
          isFalse,
          reason: 'precondition: controller already holds a selection',
        );

        await tester.pumpWidget(
          _wrap(
            ThaiAddressPicker(
              controller: controller,
              // initialCodes points at เชียงใหม่ — must be ignored because the
              // controller is already non-empty.
              initialCodes: const (50, 5001, 500108),
            ),
          ),
        );
        await tester.pump();

        expect(
          controller.province,
          equals(bangkok),
          reason:
              'pre-existing province preserved; initialCodes did not '
              'overwrite a non-empty controller',
        );
        expect(
          controller.value.toCodes(),
          equals((10, null, null)),
          reason: 'only the pre-existing Bangkok province remains',
        );
        expect(
          _dropdownValue<Province>(tester, provinceKey),
          equals(bangkok),
          reason: 'rendered province dropdown reflects the untouched selection',
        );
      },
    );
  });
}
