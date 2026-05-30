// BLIND TEST 2 (Bug-Driven Cheetah) — written from spec only.
// postcode_field.dart impl was NOT read.
//
// Spec under test (v0.4.0):
//   ThaiPostcodeField gains OPTIONAL passthrough params forwarded to its
//   subdistrict-chooser DropdownButtonFormField:
//       TextStyle? style
//       Color?     dropdownColor
//       BorderRadius? borderRadius
//       Widget?    icon
//       Color?     iconEnabledColor
//       double?    menuMaxHeight
//
//   The chooser DropdownButtonFormField (keyed
//   'thaiAddress.postcodeSubdistrict') only appears when the typed postcode
//   maps to MULTIPLE subdistricts. We drive it with the well-known ambiguous
//   postcode 50200 (3 subdistricts under province 50 / district 5001), mirrored
//   from test/postcode_field_test.dart.
//
// Assertion strategy: DropdownButtonFormField<Subdistrict> builds an inner
// DropdownButton<Subdistrict> (via DropdownButton._formField) and forwards all
// six style props onto it. We read those props from BOTH the
// DropdownButtonFormField<Subdistrict> itself AND its inner
// DropdownButton<Subdistrict>, so the test passes regardless of which surface
// Dev 2 attached the props to (as long as they actually reach the dropdown).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

/// AMBIGUOUS postcode → 3 subdistricts → forces the chooser to render.
const int kAmbiguousPostcode = 50200;

// Distinctive sentinel values, unlikely to collide with any theme default.
const TextStyle kStyle = TextStyle(
  fontSize: 27.5,
  color: Color(0xFF123456),
  fontWeight: FontWeight.w700,
);
const Color kDropdownColor = Color(0xFFABCDEF);
const BorderRadius kBorderRadius = BorderRadius.all(Radius.circular(19));
const Icon kIcon = Icon(Icons.expand_circle_down, key: Key('sentinel.icon'));
const Color kIconEnabledColor = Color(0xFF0FF1CE);
const double kMenuMaxHeight = 321.0;

Future<void> _pump(
  WidgetTester tester, {
  required ThaiAddressController controller,
  TextStyle? style,
  Color? dropdownColor,
  BorderRadius? borderRadius,
  Widget? icon,
  Color? iconEnabledColor,
  double? menuMaxHeight,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ThaiPostcodeField(
          controller: controller,
          // styled passthroughs under test:
          style: style,
          dropdownColor: dropdownColor,
          borderRadius: borderRadius,
          icon: icon,
          iconEnabledColor: iconEnabledColor,
          menuMaxHeight: menuMaxHeight,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types [text] into the postcode TextField and settles.
Future<void> _enterText(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

/// Drives the field into the chooser-shown state and returns the inner
/// [DropdownButton] of the keyed chooser (the canonical recipient of all six
/// style props), failing the test with a clear reason if no chooser appears.
DropdownButton<Subdistrict> _chooserDropdown(WidgetTester tester) {
  final chooser = find.byKey(const Key('thaiAddress.postcodeSubdistrict'));
  expect(
    chooser,
    findsOneWidget,
    reason: 'an ambiguous postcode (50200) must render the subdistrict chooser',
  );
  // The chooser is a DropdownButtonFormField<Subdistrict>; it builds an inner
  // DropdownButton<Subdistrict>. Read the inner one.
  final inner = find.descendant(
    of: chooser,
    matching: find.byType(DropdownButton<Subdistrict>),
  );
  expect(
    inner,
    findsOneWidget,
    reason: 'the chooser must build an inner DropdownButton<Subdistrict>',
  );
  return tester.widget<DropdownButton<Subdistrict>>(inner);
}

void main() {
  // Ground-truth premise guard: 50200 really is ambiguous so the chooser shows.
  final ambiguous = byPostcode(kAmbiguousPostcode);

  group('ThaiPostcodeField — chooser style passthrough', () {
    test('50200 is ambiguous (premise for the chooser to appear)', () {
      expect(
        ambiguous.length,
        greaterThan(1),
        reason: '50200 must map to several subdistricts',
      );
    });

    testWidgets(
      'forwards style/dropdownColor/borderRadius/icon/iconEnabledColor/'
      'menuMaxHeight to the subdistrict chooser dropdown',
      (tester) async {
        final controller = ThaiAddressController();
        await _pump(
          tester,
          controller: controller,
          style: kStyle,
          dropdownColor: kDropdownColor,
          borderRadius: kBorderRadius,
          icon: kIcon,
          iconEnabledColor: kIconEnabledColor,
          menuMaxHeight: kMenuMaxHeight,
        );

        // Drive to the chooser-shown state.
        await _enterText(tester, '50200');
        expect(
          controller.subdistrict,
          isNull,
          reason: 'ambiguous postcode must not auto-pick a subdistrict',
        );

        final dd = _chooserDropdown(tester);

        expect(dd.style, kStyle, reason: 'style must reach the chooser');
        expect(
          dd.dropdownColor,
          kDropdownColor,
          reason: 'dropdownColor must reach the chooser',
        );
        expect(
          dd.borderRadius,
          kBorderRadius,
          reason: 'borderRadius must reach the chooser',
        );
        expect(
          dd.iconEnabledColor,
          kIconEnabledColor,
          reason: 'iconEnabledColor must reach the chooser',
        );
        expect(
          dd.menuMaxHeight,
          kMenuMaxHeight,
          reason: 'menuMaxHeight must reach the chooser',
        );

        // The custom icon widget should be present in the chooser subtree.
        expect(
          find.descendant(
            of: find.byKey(const Key('thaiAddress.postcodeSubdistrict')),
            matching: find.byKey(const Key('sentinel.icon')),
          ),
          findsOneWidget,
          reason: 'the custom icon must reach the chooser',
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('control: with no style params, the chooser dropdown props are '
        'null/default', (tester) async {
      final controller = ThaiAddressController();
      await _pump(tester, controller: controller); // no style params

      await _enterText(tester, '50200');
      expect(controller.subdistrict, isNull);

      final dd = _chooserDropdown(tester);

      expect(dd.style, isNull, reason: 'no style → null');
      expect(dd.dropdownColor, isNull, reason: 'no dropdownColor → null');
      expect(dd.borderRadius, isNull, reason: 'no borderRadius → null');
      expect(dd.iconEnabledColor, isNull, reason: 'no iconEnabledColor → null');
      expect(dd.menuMaxHeight, isNull, reason: 'no menuMaxHeight → null');

      // Our sentinel icon must NOT be present when no icon was passed.
      expect(
        find.byKey(const Key('sentinel.icon')),
        findsNothing,
        reason: 'no custom icon was provided',
      );

      expect(tester.takeException(), isNull);
    });
  });
}
