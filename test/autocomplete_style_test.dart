import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

/// BLIND TESTER 3 (Bug-Driven Cheetah) — widget tests for the new optional
/// `style` parameter on [ThaiAddressAutocompleteField], written from the
/// contract/spec only (NOT from autocomplete_field.dart's body).
///
/// Spec: `ThaiAddressAutocompleteField` gains an OPTIONAL `TextStyle? style`
/// param forwarded to its input `TextField`. Default null = unchanged.
/// The Autocomplete builds exactly one TextField in its fieldViewBuilder.

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Finds the single editable text field rendered by the autocomplete field.
Finder get _textField => find.byType(TextField);

void main() {
  group('ThaiAddressAutocompleteField style', () {
    testWidgets('forwards the provided style to the input TextField', (
      tester,
    ) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      const style = TextStyle(color: Colors.purple, fontSize: 22);

      await tester.pumpWidget(
        _wrap(
          ThaiAddressAutocompleteField(controller: controller, style: style),
        ),
      );

      // The field must render so this is a real fail-before, not a
      // vacuous pass on a never-built widget.
      expect(_textField, findsOneWidget, reason: 'the field should render');

      final field = tester.widget<TextField>(_textField);
      expect(
        field.style,
        style,
        reason: 'the input TextField.style should equal the passed style',
      );
    });

    testWidgets(
      'leaves the input TextField.style null when no style is given (control)',
      (tester) async {
        final controller = ThaiAddressController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(ThaiAddressAutocompleteField(controller: controller)),
        );

        expect(_textField, findsOneWidget, reason: 'the field should render');

        final field = tester.widget<TextField>(_textField);
        expect(
          field.style,
          isNull,
          reason:
              'default (no style) must leave TextField.style unchanged/null',
        );
      },
    );
  });
}
