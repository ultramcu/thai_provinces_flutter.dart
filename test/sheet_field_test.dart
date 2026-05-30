// BLIND TEST (Dev B 1:1) — written from the shared SPEC only, WITHOUT reading
// lib/src/sheet_field.dart or lib/src/sheet.dart's implementations.
//
// Subject: ThaiAddressSheetField — a one-line "summary" address field that
// opens a modal bottom-sheet picker (built on showThaiAddressSheet, which in
// turn hosts a ThaiAddressPicker). Const ctor props per the contract:
//   controller (ThaiAddressController?, owns an internal one when null),
//   onChanged (ValueChanged<ThaiAddressSelection>?), language, decoration
//   (InputDecoration), enabled (bool), hint/title/confirmLabel (String?).
//
// Ground-truth (verified against package:thai_provinces):
//   subdistrict สุเทพ/Suthep 500108 -> district เมืองเชียงใหม่ 5001 ->
//   province เชียงใหม่ 50, postcode 50200.
//   selection.format() (Thai, postcode on) =>
//     'ตำบลสุเทพ อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่ 50200'
//   which contains 'สุเทพ', 'เชียงใหม่' and '50200'.
//
// These MUST fail on the throwing stub (build() throws) — that's fail-before.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// Returns true if any Text widget in the tree displays a string that
/// [predicate] accepts. Robust to the field rendering the summary inside an
/// InputDecorator / RichText / nested Text.
bool _hasTextWhere(WidgetTester tester, bool Function(String) predicate) {
  final texts = tester.widgetList<Text>(find.byType(Text));
  for (final t in texts) {
    final data = t.data;
    if (data != null && predicate(data)) return true;
  }
  // Also scan RichText (InputDecorator labels/hints can be RichText).
  final riches = tester.widgetList<RichText>(find.byType(RichText));
  for (final r in riches) {
    final s = r.text.toPlainText();
    if (predicate(s)) return true;
  }
  return false;
}

bool _hasTextContaining(WidgetTester tester, String needle) =>
    _hasTextWhere(tester, (s) => s.contains(needle));

void main() {
  // Ground-truth selection used for the formatted-summary assertions.
  final completeSelection = ThaiAddressSelection.fromCodes(
    subdistrictCode: 500108,
  );

  group('ThaiAddressSheetField — empty state', () {
    testWidgets('shows the default hint and no formatted address line', (
      tester,
    ) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(ThaiAddressSheetField(controller: controller)),
      );
      await tester.pump();

      // Default hint is visible.
      expect(
        _hasTextContaining(tester, 'เลือกที่อยู่'),
        isTrue,
        reason: 'default hint "เลือกที่อยู่" should be shown when empty',
      );

      // No formatted-address fragments are shown while empty.
      expect(
        _hasTextContaining(tester, 'จังหวัด'),
        isFalse,
        reason:
            'no formatted address line should render for an empty selection',
      );
      expect(
        _hasTextContaining(tester, '50200'),
        isFalse,
        reason: 'no postcode should render for an empty selection',
      );
    });

    testWidgets('a custom hint override is shown when empty', (tester) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(ThaiAddressSheetField(controller: controller, hint: 'X')),
      );
      await tester.pump();

      expect(
        _hasTextWhere(tester, (s) => s == 'X' || s.contains('X')),
        isTrue,
        reason: 'custom hint "X" should be shown when empty',
      );
    });
  });

  group('ThaiAddressSheetField — programmatic controller drive', () {
    testWidgets(
      'setFromCodes(subdistrictCode: 500108) renders the formatted summary',
      (tester) async {
        final controller = ThaiAddressController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(ThaiAddressSheetField(controller: controller)),
        );
        await tester.pump();

        // Precondition: it's the empty/hint state.
        expect(_hasTextContaining(tester, '50200'), isFalse);

        // Drive the controller programmatically.
        controller.setFromCodes(subdistrictCode: 500108);
        await tester.pump();

        // The field must now render the formatted address (matches
        // controller.value.format()): contains สุเทพ, เชียงใหม่ and 50200.
        final expected = controller.value.format();
        expect(
          expected.contains('สุเทพ') &&
              expected.contains('เชียงใหม่') &&
              expected.contains('50200'),
          isTrue,
          reason: 'sanity: ground-truth format() string built as expected',
        );

        expect(
          _hasTextContaining(tester, 'สุเทพ'),
          isTrue,
          reason: 'summary should contain the subdistrict สุเทพ',
        );
        expect(
          _hasTextContaining(tester, 'เชียงใหม่'),
          isTrue,
          reason: 'summary should contain the province เชียงใหม่',
        );
        expect(
          _hasTextContaining(tester, '50200'),
          isTrue,
          reason: 'summary should contain the postcode 50200',
        );

        // The default hint must no longer be shown once a value is set.
        expect(
          _hasTextWhere(tester, (s) => s == 'เลือกที่อยู่'),
          isFalse,
          reason: 'hint replaced by the formatted summary once a value is set',
        );
      },
    );
  });

  group('ThaiAddressSheetField — tap opens the sheet', () {
    // Drives a cascading DropdownButtonFormField (keyed) to a value by visible
    // label text. The dropdown menu is rendered in an overlay after a tap.
    Future<void> selectFromDropdown(
      WidgetTester tester,
      Key key,
      String label,
    ) async {
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      // The menu item carrying the label (the last match is the overlay copy).
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'tapping opens a ThaiAddressPicker seeded from the controller; confirming '
      'a change fires onChanged & keeps a complete selection',
      (tester) async {
        // Seed COMPLETE (สุเทพ 500108). The sheet is seeded from the controller,
        // so its picker opens already at this selection.
        final controller = ThaiAddressController(initial: completeSelection);
        addTearDown(controller.dispose);

        ThaiAddressSelection? changed;
        await tester.pumpWidget(
          _wrap(
            ThaiAddressSheetField(
              controller: controller,
              onChanged: (sel) => changed = sel,
            ),
          ),
        );
        await tester.pump();

        // Tap the field to open the sheet.
        await tester.tap(find.byType(ThaiAddressSheetField));
        await tester.pumpAndSettle();

        // A modal sheet hosting the cascading picker is open, seeded from the
        // controller (its summary content is present in the open sheet).
        expect(
          find.byType(ThaiAddressPicker),
          findsOneWidget,
          reason:
              'tapping the field opens a sheet containing a ThaiAddressPicker',
        );
        expect(
          _hasTextContaining(tester, 'สุเทพ'),
          isTrue,
          reason: 'the sheet was seeded from the controller (shows สุเทพ)',
        );

        // Change the subdistrict (within the same district/province) to ศรีภูมิ
        // (500101) so the confirm commits an OBSERVABLE change.
        await selectFromDropdown(
          tester,
          const Key('thaiAddress.subdistrict'),
          'ศรีภูมิ',
        );

        // Tap the confirm/primary button to commit.
        final buttons = find.byWidgetPredicate(
          (w) => w is ButtonStyleButton, // Filled/Elevated/TextButton
        );
        expect(
          buttons,
          findsWidgets,
          reason: 'the sheet should expose a confirm button',
        );
        await tester.tap(buttons.last);
        await tester.pumpAndSettle();

        // The sheet closed.
        expect(
          find.byType(ThaiAddressPicker),
          findsNothing,
          reason: 'confirming closes the sheet',
        );

        // onChanged fired and the controller still holds a complete selection.
        expect(
          changed,
          isNotNull,
          reason: 'onChanged should fire when the sheet commits a change',
        );
        expect(
          controller.value.isComplete,
          isTrue,
          reason: 'a complete selection is still held after confirm',
        );
        expect(
          controller.value.toCodes(),
          equals((50, 5001, 500101)),
          reason: 'the confirmed (changed) selection round-trips to ศรีภูมิ',
        );
        // The field summary reflects the committed change.
        expect(_hasTextContaining(tester, 'ศรีภูมิ'), isTrue);
      },
    );
  });
}
