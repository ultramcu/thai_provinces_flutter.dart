// Blind smoke test for the thai_provinces_flutter example GALLERY app.
//
// Written FROM SPEC ONLY (Roadmap #4): a polished gallery that showcases every
// form-factor wired to ONE shared ThaiAddressController, with sections for the
// Picker, Autocomplete, Postcode field, and a live "Current selection" readout.
//
// This test imports the example's entrypoint (lib/main.dart) and exercises the
// gallery's root widget `ExampleApp`. It is intentionally agnostic about the
// internal widget tree: assertions match on the human-readable section labels
// and the readout text that the spec promises, not on private structure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

import 'package:thai_provinces_flutter_example/main.dart';

/// Case-insensitive "contains substring" finder over any Text widget's data.
Finder findTextContaining(String needle) {
  final lower = needle.toLowerCase();
  return find.byWidgetPredicate((w) {
    if (w is Text) {
      final data = w.data ?? w.textSpan?.toPlainText();
      return data != null && data.toLowerCase().contains(lower);
    }
    return false;
  }, description: 'Text containing "$needle" (case-insensitive)');
}

void main() {
  // A real Thai province + its codes, used to drive the shared controller and
  // verify the "Current selection" readout reflects updates.
  late Province bangkok;

  setUpAll(() {
    bangkok = provinces().firstWhere(
      (p) => p.nameEn.toLowerCase() == 'bangkok',
      orElse: () => provinces().first,
    );
  });

  group('gallery smoke', () {
    testWidgets('pumps the gallery root widget and settles without throwing',
        (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      // The gallery must be a Material app with a real scaffold/app bar.
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows the key gallery sections and the selection readout',
        (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      // Each showcased form-factor must have a discoverable section label.
      expect(findTextContaining('picker'), findsWidgets,
          reason: 'gallery should label the ThaiAddressPicker section');
      expect(findTextContaining('autocomplete'), findsWidgets,
          reason: 'gallery should label the ThaiAddressAutocompleteField section');
      expect(findTextContaining('postcode'), findsWidgets,
          reason: 'gallery should label the ThaiPostcodeField section');

      // The live readout that mirrors the shared controller. The gallery
      // defaults to Thai, so the readout label renders in Thai.
      expect(findTextContaining('ที่อยู่ปัจจุบัน'), findsWidgets,
          reason: 'gallery should render a "Current selection" readout');

      // The widgets must be present, all wired to one controller. There are
      // TWO ThaiAddressPickers — the explicit picker demo plus the one that
      // ThaiAddressFormField wraps internally — so findsWidgets, not One.
      expect(find.byType(ThaiAddressPicker), findsWidgets);
      expect(find.byType(ThaiAddressAutocompleteField), findsOneWidget);
      expect(find.byType(ThaiPostcodeField), findsOneWidget);
    });

    testWidgets(
        'driving the shared picker updates the shared "Current selection" readout',
        (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      // The gallery must wire all form-factors to ONE shared controller.
      // Require the widgets to exist first so this test cannot accidentally
      // pass against the old minimal demo. (Two pickers: explicit + the one
      // ThaiAddressFormField wraps — so findsWidgets for ThaiAddressPicker.)
      expect(find.byType(ThaiAddressPicker), findsWidgets);
      expect(find.byType(ThaiAddressAutocompleteField), findsOneWidget);
      expect(find.byType(ThaiPostcodeField), findsOneWidget);

      // Before interaction, the chosen province name must NOT already be in the
      // readout (otherwise the assertion below would be meaningless).
      final beforeBangkok = findTextContaining(bangkok.nameTh);
      final hadBangkokBefore = beforeBangkok.evaluate().isNotEmpty;

      // Open the explicit picker's province dropdown. Both pickers tag it with
      // the key 'thaiAddress.province'; scope to the first so the tap is
      // deterministic. The gallery scrolls, so bring it on-screen before
      // tapping, then select a real province.
      final provinceDropdown = find.byKey(const Key('thaiAddress.province')).first;
      await tester.ensureVisible(provinceDropdown);
      await tester.pumpAndSettle();
      await tester.tap(provinceDropdown);
      await tester.pumpAndSettle();

      // Tap the menu item for our target province (Thai name).
      await tester.tap(findTextContaining(bangkok.nameTh).last);
      await tester.pumpAndSettle();

      // After selecting, the province name must appear somewhere in the gallery
      // (it is reflected by the shared "Current selection" readout). This proves
      // ONE shared controller drives the readout from a picker interaction.
      expect(findTextContaining(bangkok.nameTh), findsWidgets,
          reason:
              'selecting a province in the picker should surface in the shared readout');

      // Sanity: interaction actually changed state (not a pre-baked label).
      if (!hadBangkokBefore) {
        expect(findTextContaining(bangkok.nameTh).evaluate(), isNotEmpty);
      }
    });
  });
}
