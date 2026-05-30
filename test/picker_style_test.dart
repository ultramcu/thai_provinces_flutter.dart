// BLIND TEST 1 (Dev1 1:1) — written from the shared SPEC only, WITHOUT reading
// the wiring inside lib/src/picker.dart. Exercises the new OPTIONAL styling
// passthrough params of ThaiAddressPicker that forward to each of its three
// DropdownButtonFormFields (province / district / subdistrict):
//
//   TextStyle?    style
//   Color?        dropdownColor
//   BorderRadius? borderRadius
//   Widget?       icon
//   Color?        iconEnabledColor
//   double?       menuMaxHeight
//
// Contract: each param defaults to null (unchanged). When supplied, the SAME
// value must reach all three dropdowns.
//
// IMPLEMENTATION NOTE (verified against Flutter 3.24.5 framework source):
//   DropdownButtonFormField<T> is a FormField<T> and does NOT re-expose
//   style/dropdownColor/icon/iconEnabledColor/menuMaxHeight/borderRadius as
//   public getters. Those getters live on the inner DropdownButton<T> that the
//   form field builds (dropdown.dart: DropdownButton class @960 exposes them;
//   DropdownButtonFormField @1745 does not). So we descend from each keyed
//   DropdownButtonFormField to its inner DropdownButton<T> and assert there.
//
// These assertions MUST fail on the current stub (params absent / unwired) —
// that's the fail-before.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

// Field keys used by the picker's default dropdowns (same convention as the
// other picker tests).
const provinceKey = Key('thaiAddress.province');
const districtKey = Key('thaiAddress.district');
const subdistrictKey = Key('thaiAddress.subdistrict');

// Returns the inner DropdownButton<T> that the keyed DropdownButtonFormField<T>
// renders. Fails the test (findsOneWidget) if exactly one isn't found.
DropdownButton<T> _innerButton<T>(WidgetTester tester, Key fieldKey) {
  final finder = find.descendant(
    of: find.byKey(fieldKey),
    matching: find.byType(DropdownButton<T>),
  );
  expect(
    finder,
    findsOneWidget,
    reason: 'expected exactly one inner DropdownButton under $fieldKey',
  );
  return tester.widget<DropdownButton<T>>(finder);
}

void main() {
  group('ThaiAddressPicker styling passthrough', () {
    const style = TextStyle(color: Colors.red);
    const dropdownColor = Colors.amber;
    final borderRadius = BorderRadius.circular(20);
    const icon = Icon(Icons.expand_more, key: Key('customIcon'));
    const iconEnabledColor = Colors.green;
    const menuMaxHeight = 240.0;

    testWidgets('all six style params reach every dropdown', (tester) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          ThaiAddressPicker(
            controller: controller,
            style: style,
            dropdownColor: dropdownColor,
            borderRadius: borderRadius,
            icon: icon,
            iconEnabledColor: iconEnabledColor,
            menuMaxHeight: menuMaxHeight,
          ),
        ),
      );
      await tester.pump();

      void assertCarries<T>(Key key, String label) {
        final dd = _innerButton<T>(tester, key);

        expect(
          dd.style,
          equals(style),
          reason: '$label dropdown should carry the passed TextStyle',
        );
        expect(
          dd.dropdownColor,
          equals(dropdownColor),
          reason: '$label dropdown should carry the passed dropdownColor',
        );
        expect(
          dd.borderRadius,
          equals(borderRadius),
          reason: '$label dropdown should carry the passed borderRadius',
        );
        expect(
          dd.iconEnabledColor,
          equals(iconEnabledColor),
          reason: '$label dropdown should carry the passed iconEnabledColor',
        );
        expect(
          dd.menuMaxHeight,
          equals(menuMaxHeight),
          reason: '$label dropdown should carry the passed menuMaxHeight',
        );
        // icon: type + key + glyph check (the forwarded Icon).
        expect(
          dd.icon,
          isA<Icon>(),
          reason: '$label dropdown icon should be the passed Icon',
        );
        expect(
          (dd.icon! as Icon).key,
          equals(const Key('customIcon')),
          reason: '$label dropdown icon should carry the passed key',
        );
        expect(
          (dd.icon! as Icon).icon,
          equals(Icons.expand_more),
          reason: '$label dropdown icon should be Icons.expand_more',
        );
      }

      assertCarries<Province>(provinceKey, 'province');
      assertCarries<District>(districtKey, 'district');
      assertCarries<Subdistrict>(subdistrictKey, 'subdistrict');
    });

    testWidgets(
      'defaults: with no style params each dropdown leaves them null',
      (tester) async {
        final controller = ThaiAddressController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(ThaiAddressPicker(controller: controller)),
        );
        await tester.pump();

        void assertDefaults<T>(Key key, String label) {
          final dd = _innerButton<T>(tester, key);
          expect(
            dd.style,
            isNull,
            reason: '$label dropdown style should default to null',
          );
          expect(
            dd.dropdownColor,
            isNull,
            reason: '$label dropdown dropdownColor should default to null',
          );
          expect(
            dd.borderRadius,
            isNull,
            reason: '$label dropdown borderRadius should default to null',
          );
          expect(
            dd.iconEnabledColor,
            isNull,
            reason: '$label dropdown iconEnabledColor should default to null',
          );
          expect(
            dd.menuMaxHeight,
            isNull,
            reason: '$label dropdown menuMaxHeight should default to null',
          );
          // icon: when not supplied it must NOT be our custom keyed icon.
          final ddIcon = dd.icon;
          if (ddIcon is Icon) {
            expect(
              ddIcon.key,
              isNot(equals(const Key('customIcon'))),
              reason:
                  '$label dropdown should not use the custom icon by default',
            );
          }
        }

        assertDefaults<Province>(provinceKey, 'province');
        assertDefaults<District>(districtKey, 'district');
        assertDefaults<Subdistrict>(subdistrictKey, 'subdistrict');
      },
    );
  });
}
