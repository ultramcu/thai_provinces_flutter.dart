// Test for ThaiAddressSearchField — a one-line "summary" address field that
// opens a full-screen search (showThaiAddressSearch) on tap; picking a result
// commits the selection to the controller. Mirrors the sheet_field_test idiom.
//
// Ground-truth (package:thai_provinces): subdistrict สุเทพ/Suthep 500108 ->
// district เมืองเชียงใหม่ 5001 -> province เชียงใหม่ 50, postcode 50200;
// selection.format() => 'ตำบลสุเทพ อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่ 50200'.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

bool _hasTextWhere(WidgetTester tester, bool Function(String) predicate) {
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final data = t.data;
    if (data != null && predicate(data)) return true;
  }
  for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
    if (predicate(r.text.toPlainText())) return true;
  }
  return false;
}

bool _hasTextContaining(WidgetTester tester, String needle) =>
    _hasTextWhere(tester, (s) => s.contains(needle));

void main() {
  group('ThaiAddressSearchField — empty state', () {
    testWidgets('shows the default hint when empty', (tester) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(ThaiAddressSearchField(controller: controller)),
      );
      await tester.pump();

      expect(
        _hasTextContaining(tester, 'เลือกที่อยู่'),
        isTrue,
        reason: 'default hint should show when empty',
      );
      expect(_hasTextContaining(tester, '50200'), isFalse);
    });

    testWidgets('a custom hint override is shown when empty', (tester) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(ThaiAddressSearchField(controller: controller, hint: 'XYZ')),
      );
      await tester.pump();

      expect(_hasTextContaining(tester, 'XYZ'), isTrue);
    });
  });

  group('ThaiAddressSearchField — programmatic drive', () {
    testWidgets('setFromCodes(500108) renders the formatted summary', (
      tester,
    ) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(ThaiAddressSearchField(controller: controller)),
      );
      await tester.pump();
      expect(_hasTextContaining(tester, '50200'), isFalse);

      controller.setFromCodes(subdistrictCode: 500108);
      await tester.pump();

      expect(_hasTextContaining(tester, 'สุเทพ'), isTrue);
      expect(_hasTextContaining(tester, 'เชียงใหม่'), isTrue);
      expect(_hasTextContaining(tester, '50200'), isTrue);
      expect(
        _hasTextWhere(tester, (s) => s == 'เลือกที่อยู่'),
        isFalse,
        reason: 'hint is replaced by the summary once a value is set',
      );
    });
  });

  group('ThaiAddressSearchField — tap opens full-screen search', () {
    testWidgets('typing + picking a result commits to the controller and '
        'fires onChanged', (tester) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      ThaiAddressSelection? changed;
      await tester.pumpWidget(
        _wrap(
          ThaiAddressSearchField(
            controller: controller,
            onChanged: (sel) => changed = sel,
          ),
        ),
      );
      await tester.pump();

      // Tap the field -> full-screen search route opens.
      await tester.tap(find.byType(ThaiAddressSearchField));
      await tester.pumpAndSettle();

      // The search field (a TextField hosted in the search AppBar) is present.
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'tapping opens a full-screen search with a TextField',
      );

      // Type a query and pick the matching breadcrumb result.
      await tester.enterText(find.byType(TextField), 'สุเทพ');
      await tester.pumpAndSettle();
      expect(
        _hasTextContaining(tester, 'สุเทพ'),
        isTrue,
        reason: 'a breadcrumb result for สุเทพ should appear',
      );
      await tester.tap(find.textContaining('สุเทพ').first);
      await tester.pumpAndSettle();

      // Search closed; the pick committed a complete Chiang Mai selection.
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'picking a result closes the search',
      );
      expect(controller.value.isComplete, isTrue);
      expect(controller.value.province?.code, 50);
      expect(controller.value.subdistrict?.code, 500108);
      expect(changed, isNotNull);
      expect(changed?.subdistrict?.code, 500108);

      // The field summary now reflects the committed selection.
      expect(_hasTextContaining(tester, 'สุเทพ'), isTrue);
    });

    testWidgets('dismissing the search leaves the selection unchanged', (
      tester,
    ) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(ThaiAddressSearchField(controller: controller)),
      );
      await tester.pump();

      await tester.tap(find.byType(ThaiAddressSearchField));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // Dismiss via the leading back affordance.
      final back = find.byTooltip('Back').evaluate().isNotEmpty
          ? find.byTooltip('Back')
          : find.byType(BackButton);
      await tester.tap(back.first);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(
        controller.value.isEmpty,
        isTrue,
        reason: 'a dismissed search must not change the selection',
      );
    });
  });
}
