// BLIND TEST (Dev1 1:1) — written from the shared SPEC only, WITHOUT reading
// the wiring inside lib/src/picker.dart. Exercises the two new builder params
// of ThaiAddressPicker:
//
//   * fieldBuilder (ThaiAddressFieldBuilder?): for a given level, may return a
//     custom Widget (the picker uses it instead of the default dropdown), or
//     null to fall back to the default DropdownButtonFormField. The custom
//     widget commits a selection by calling scope.onSelected(option); the
//     picker then runs the normal cascade into the controller.
//   * labelBuilder (ThaiAddressLabelBuilder?): overrides the display label of
//     each area model (Province/District/Subdistrict) in the default fields.
//
// Public contracts used (from the SPEC + exported type declarations):
//   enum ThaiAddressLevel { province, district, subdistrict }
//   class ThaiAddressFieldScope {
//     ThaiAddressLevel level; List<Object> options; Object? selected;
//     ValueChanged<Object?> onSelected; bool enabled; String label;
//   }
//   typedef ThaiAddressFieldBuilder =
//       Widget? Function(BuildContext, ThaiAddressFieldScope);
//   typedef ThaiAddressLabelBuilder = String Function(Object area);
//
// Ground-truth (verified against package:thai_provinces):
//   * province เชียงใหม่/Chiang Mai has code 50 (used for the fieldBuilder
//     cascade: scope.onSelected(option-with-code-50) -> controller province 50).
//   * province กรุงเทพมหานคร/Bangkok has code 10 and sits at the top of the
//     province list, so its menu item is laid out in the initial open-dropdown
//     viewport. Its default (Thai) label is 'กรุงเทพมหานคร', so a labelBuilder
//     emitting 'X-10' is clearly distinguishable from the default. (Chiang
//     Mai's 'X-50' item is far down the 77-item list and is NOT laid out until
//     scrolled, which is a ListView viewport detail — not a labelling concern —
//     so the override is asserted on the in-viewport Bangkok item.)
//
// These MUST fail on the current stub (fieldBuilder + labelBuilder are present
// but UNWIRED) — that's the fail-before.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

// Keys used by the picker's default fields (same convention exercised by the
// other picker tests).
const provinceKey = Key('thaiAddress.province');
const districtKey = Key('thaiAddress.district');
const subdistrictKey = Key('thaiAddress.subdistrict');

void main() {
  group('ThaiAddressPicker(fieldBuilder:)', () {
    testWidgets('custom province field renders, taps, and drives the cascade', (
      tester,
    ) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      // The fieldBuilder supplies a custom widget for the PROVINCE level only
      // (an ElevatedButton keyed customProvince that, when tapped, selects the
      // province whose code == 50 via scope.onSelected). For every other
      // level it returns null, so those keep the default dropdown.
      var provinceBuildCount = 0;
      await tester.pumpWidget(
        _wrap(
          ThaiAddressPicker(
            controller: controller,
            fieldBuilder: (context, scope) {
              if (scope.level == ThaiAddressLevel.province) {
                provinceBuildCount++;
                return ElevatedButton(
                  key: const Key('customProvince'),
                  onPressed: () => scope.onSelected(
                    scope.options.firstWhere((o) => (o as Province).code == 50),
                  ),
                  child: const Text('pick CM'),
                );
              }
              return null; // default dropdown for district/subdistrict
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The custom widget must be present (fieldBuilder honoured)...
      expect(
        find.byKey(const Key('customProvince')),
        findsOneWidget,
        reason: 'fieldBuilder custom province widget should render',
      );
      expect(
        provinceBuildCount,
        greaterThan(0),
        reason: 'picker invoked the fieldBuilder for the province level',
      );

      // ...and the DEFAULT province dropdown must NOT be present (the custom
      // widget replaces it, it does not render alongside it).
      expect(
        find.byKey(provinceKey),
        findsNothing,
        reason: 'custom province field replaces the default dropdown',
      );

      // Levels that returned null keep their default dropdown.
      expect(
        find.byKey(districtKey),
        findsOneWidget,
        reason: 'district returned null -> default dropdown still rendered',
      );
      expect(
        tester.widget<DropdownButtonFormField<District>>(
          find.byKey(districtKey),
        ),
        isNotNull,
        reason: 'null-returning level falls back to DropdownButtonFormField',
      );

      // Tapping the custom widget commits the selection through onSelected;
      // the picker must run the cascade into the controller.
      await tester.tap(find.byKey(const Key('customProvince')));
      await tester.pumpAndSettle();

      expect(
        controller.value.province?.code,
        equals(50),
        reason: 'scope.onSelected wired the cascade -> controller province set',
      );
    });
  });

  group('ThaiAddressPicker(labelBuilder:)', () {
    testWidgets(
      'labelBuilder overrides the option label in the province dropdown',
      (tester) async {
        final controller = ThaiAddressController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            ThaiAddressPicker(
              controller: controller,
              labelBuilder: (area) =>
                  'X-${area is Province ? area.code.toString() : '?'}',
            ),
          ),
        );
        await tester.pump();

        // Open the province dropdown.
        await tester.tap(find.byKey(provinceKey));
        await tester.pumpAndSettle();

        // The open menu lists all 77 provinces in a scrollable, and only the
        // items in the current viewport are laid out — so we must NOT assume any
        // particular code is on screen at the initial scroll offset (which is
        // what made this test flaky under full-suite load). Scroll the menu
        // until the Bangkok (code 10) item is brought into view, then assert on
        // it. `dragUntilVisible` is a no-op (and still succeeds) when the target
        // is already visible, so this is robust either way.
        final menu = find.byType(Scrollable).last;
        final bangkokOverride = find.text('X-10');
        await tester.dragUntilVisible(
          bangkokOverride,
          menu,
          const Offset(0, -50),
        );
        await tester.pumpAndSettle();

        // The Bangkok province item must show the custom label 'X-10' produced
        // by the labelBuilder, rather than its default Thai name.
        expect(
          bangkokOverride,
          findsWidgets,
          reason: 'labelBuilder should override the default province label',
        );

        // The default Thai label for Bangkok must NOT be present anywhere the
        // override applies. (It only ever exists as an option label, so once the
        // override is in effect it should appear nowhere — including off-screen,
        // since the labelBuilder, not the viewport, decides the text.)
        expect(
          find.text('กรุงเทพมหานคร'),
          findsNothing,
          reason: 'default Thai label must be overridden by labelBuilder',
        );
      },
    );
  });
}
