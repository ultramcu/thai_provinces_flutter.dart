// BLIND TESTER 4 (1:1 with Dev4) — accessibility wiring, written from the
// spec/contract ONLY (postcode_field.dart and autocomplete_field.dart bodies
// were NOT read).
//
// Asserts the a11y attributes Dev4 is adding:
//   * ThaiPostcodeField's text field advertises AutofillHints.postalCode so
//     platform autofill / password managers offer the postcode.
//   * ThaiAddressAutocompleteField is announceable by screen readers: it has
//     either a discoverable semantics label or a TextField with a non-empty
//     decoration label.
//
// These FAIL BEFORE Dev4 wires the attributes (no autofillHints / no label),
// and PASS AFTER.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('ThaiPostcodeField — autofill a11y', () {
    testWidgets('the postcode TextField advertises AutofillHints.postalCode', (
      tester,
    ) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(ThaiPostcodeField(controller: controller)));
      await tester.pumpAndSettle();

      // The widget must build and render exactly one editable field.
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'the postcode field should render a single TextField',
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.autofillHints,
        isNotNull,
        reason: 'the postcode field must declare autofillHints',
      );
      expect(
        field.autofillHints,
        contains(AutofillHints.postalCode),
        reason:
            'screen readers / autofill need the postalCode hint so the '
            'platform can offer a postcode',
      );
    });
  });

  group('ThaiAddressAutocompleteField — screen-reader announceable', () {
    testWidgets(
      'has a discoverable semantics label or a non-empty TextField label',
      (tester) async {
        final controller = ThaiAddressController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(ThaiAddressAutocompleteField(controller: controller)),
        );
        await tester.pumpAndSettle();

        // The field must build and render an editable field at all (this also
        // makes the test fail-before against an unimplemented stub rather than
        // trivially passing).
        final textFieldFinder = find.byType(TextField);
        expect(
          textFieldFinder,
          findsOneWidget,
          reason: 'the autocomplete field should render a single TextField',
        );

        // Path 1: a non-empty decoration label on the TextField.
        final field = tester.widget<TextField>(textFieldFinder);
        final decoration = field.decoration;
        final labelWidget = decoration?.label;
        final labelText = decoration?.labelText;
        final hasNonEmptyDecorationLabel =
            (labelText != null && labelText.trim().isNotEmpty) ||
            labelWidget != null;

        // Path 2: a discoverable semantics label anywhere in the subtree.
        // Probe via the SemanticsLabel matcher; any non-empty label satisfies.
        var hasSemanticsLabel = false;
        for (final candidate in <String>{
          // The decoration label text, if any, would also surface here, but we
          // primarily look for an explicit Semantics(label: ...) wrapper. We
          // can't know the exact string from spec, so we discover it from the
          // rendered semantics tree instead of guessing.
        }) {
          if (find.bySemanticsLabel(candidate).evaluate().isNotEmpty) {
            hasSemanticsLabel = true;
            break;
          }
        }

        // Discover any non-empty semantics label in the tree (no guessing the
        // exact string). A field that is announceable will expose at least one
        // node whose semantics label is non-empty and contains real text.
        if (!hasSemanticsLabel) {
          hasSemanticsLabel = find
              .bySemanticsLabel(RegExp(r'\S'))
              .evaluate()
              .isNotEmpty;
        }

        expect(
          hasNonEmptyDecorationLabel || hasSemanticsLabel,
          isTrue,
          reason:
              'the autocomplete field must be announceable by screen '
              'readers: provide a Semantics label or a non-empty decoration '
              'label',
        );
      },
    );
  });
}
