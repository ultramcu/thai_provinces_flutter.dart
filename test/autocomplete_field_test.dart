import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

/// BLIND TESTER A — widget tests for [ThaiAddressAutocompleteField], written
/// from the contract/spec only (NOT from autocomplete_field.dart's body).
///
/// Known data facts used as deterministic fixtures:
///  * subdistrict "สุเทพ"/"Suthep" is in district เมืองเชียงใหม่
///    (Mueang Chiang Mai), province เชียงใหม่ (Chiang Mai, code 50),
///    postcode 50200.

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Finds the single editable text field rendered by the autocomplete field.
Finder get _textField => find.byType(TextField);

void main() {
  group('ThaiAddressAutocompleteField', () {
    testWidgets(
      'typing สุเทพ and picking the first option fills the controller '
      'and fires onChanged with a complete Chiang Mai selection',
      (tester) async {
        final controller = ThaiAddressController();
        addTearDown(controller.dispose);

        final fired = <ThaiAddressSelection>[];

        await tester.pumpWidget(
          _wrap(
            ThaiAddressAutocompleteField(
              controller: controller,
              onChanged: fired.add,
            ),
          ),
        );

        // Type a deterministic query with a tiny result set.
        await tester.enterText(_textField, 'สุเทพ');
        await tester.pumpAndSettle();

        // The options overlay should now contain at least one option. The
        // option label is the suggestion's display string, which for Thai
        // contains the subdistrict name "สุเทพ" and the province "เชียงใหม่".
        final optionFinder = find.textContaining('สุเทพ').hitTestable();
        expect(
          optionFinder,
          findsWidgets,
          reason: 'an options overlay with a สุเทพ suggestion should appear',
        );

        // Tap the first option in the overlay (skip the field's own text by
        // taking the last match — the overlay renders below the field).
        await tester.tap(optionFinder.last);
        await tester.pumpAndSettle();

        // The controller must now hold the complete Chiang Mai selection.
        final value = controller.value;
        expect(value.isComplete, isTrue, reason: 'selection should complete');
        expect(value.province?.code, 50, reason: 'Chiang Mai is code 50');
        expect(value.postcode, 50200, reason: 'สุเทพ postcode is 50200');

        // onChanged must have fired with that same complete selection.
        expect(fired, isNotEmpty, reason: 'onChanged should fire on pick');
        final last = fired.last;
        expect(last.isComplete, isTrue);
        expect(last.province?.code, 50);
        expect(last.postcode, 50200);
        expect(
          last,
          controller.value,
          reason: 'onChanged value should match controller value',
        );
      },
    );

    testWidgets('empty text shows no options overlay', (tester) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(ThaiAddressAutocompleteField(controller: controller)),
      );

      // The field itself must render (build must succeed). This makes the
      // test fail-before against the UnimplementedError stub instead of
      // trivially passing on "no options" when nothing built at all.
      expect(_textField, findsOneWidget, reason: 'the field should render');

      // Open the field but leave it empty.
      await tester.tap(_textField);
      await tester.enterText(_textField, '');
      await tester.pumpAndSettle();

      // No option tiles should be rendered for an empty query. We assert there
      // is no ListView (the standard Autocomplete options container) and no
      // tappable InkWell options in an overlay.
      expect(
        find.byType(ListView),
        findsNothing,
        reason: 'empty query must not render an options list',
      );
    });

    testWidgets(
      'field text after selection equals the suggestion display string',
      (tester) async {
        final controller = ThaiAddressController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(ThaiAddressAutocompleteField(controller: controller)),
        );

        await tester.enterText(_textField, 'สุเทพ');
        await tester.pumpAndSettle();

        final optionFinder = find.textContaining('สุเทพ').hitTestable();
        expect(optionFinder, findsWidgets);
        await tester.tap(optionFinder.last);
        await tester.pumpAndSettle();

        // Reconstruct the expected display string from the committed selection
        // via the suggestion's own display() (Thai is the default language).
        final value = controller.value;
        final suggestion = ThaiAddressSuggestion(
          province: value.province!,
          district: value.district!,
          subdistrict: value.subdistrict!,
        );
        final expected = suggestion.display(ThaiAddressLanguage.thai);

        final field = tester.widget<TextField>(_textField);
        expect(
          field.controller?.text,
          expected,
          reason: 'field text should equal the picked suggestion label',
        );
      },
    );
  });
}
