// BLIND TEST (Tester A) for showThaiAddressSheet — written FROM SPEC ONLY.
//
// Contract under test:
//   Future<ThaiAddressSelection?> showThaiAddressSheet(
//     BuildContext context, {
//     ThaiAddressSelection? initial,
//     ThaiAddressLanguage language = ThaiAddressLanguage.thai,
//     String? title,
//     String? confirmLabel,
//   })
//
// The sheet is a stock modal bottom sheet whose body hosts a ThaiAddressPicker.
// Confirming resolves the future with the current selection; dismissing
// (scrim / back / cancel) resolves it with null.
//
// Test data (DOPA codes, verified against the embedded dataset elsewhere):
//   subdistrict 500108 (สุเทพ/Suthep) -> district 5001 -> province 50 (Chiang Mai)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

/// Pumps a MaterialApp with a single button that, when tapped, opens the
/// sheet and stashes the returned future for the test to await.
///
/// Returns a getter that yields the captured future (null until the button
/// has been tapped).
Future<Future<ThaiAddressSelection?>? Function()> _pumpLauncher(
  WidgetTester tester, {
  ThaiAddressSelection? initial,
  ThaiAddressLanguage language = ThaiAddressLanguage.thai,
  String? title,
  String? confirmLabel,
}) async {
  Future<ThaiAddressSelection?>? future;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              future = showThaiAddressSheet(
                context,
                initial: initial,
                language: language,
                title: title,
                confirmLabel: confirmLabel,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  return () => future;
}

void main() {
  group('showThaiAddressSheet — opens', () {
    testWidgets('shows a ThaiAddressPicker and the heading in the sheet', (
      tester,
    ) async {
      const heading = 'เลือกที่อยู่';
      await _pumpLauncher(
        tester,
        initial: ThaiAddressSelection.fromCodes(provinceCode: 50),
        title: heading,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The picker is mounted inside the bottom sheet.
      expect(
        find.byType(ThaiAddressPicker),
        findsOneWidget,
        reason: 'the sheet body must host a ThaiAddressPicker',
      );

      // The heading (title) text is shown.
      expect(
        find.text(heading),
        findsOneWidget,
        reason: 'the provided title must be rendered as the sheet heading',
      );
    });

    testWidgets('uses a modal bottom sheet route', (tester) async {
      await _pumpLauncher(
        tester,
        initial: ThaiAddressSelection.fromCodes(provinceCode: 50),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Stock showModalBottomSheet renders its content inside a BottomSheet.
      expect(find.byType(BottomSheet), findsOneWidget);
      // The picker is reachable from within that sheet.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(ThaiAddressPicker),
        ),
        findsOneWidget,
      );
    });
  });

  group('showThaiAddressSheet — confirm', () {
    testWidgets(
      'tapping confirm resolves the future with the current selection',
      (tester) async {
        // Seed a COMPLETE selection so the picker opens already-complete and
        // confirm is meaningful without driving three dropdowns.
        final getFuture = await _pumpLauncher(
          tester,
          initial: ThaiAddressSelection.fromCodes(subdistrictCode: 500108),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final future = getFuture();
        expect(future, isNotNull, reason: 'the launcher captured no future');

        // The default confirm label is the Thai 'ยืนยัน'.
        final confirm = find.text('ยืนยัน');
        expect(
          confirm,
          findsOneWidget,
          reason: 'a confirm affordance labelled ยืนยัน must be present',
        );

        await tester.tap(confirm);
        await tester.pumpAndSettle();

        final result = await future!;
        expect(result, isNotNull, reason: 'confirm must resolve non-null');
        expect(result!.province?.code, 50);
        expect(result.subdistrict?.code, 500108);
      },
    );

    testWidgets('honours a custom confirmLabel', (tester) async {
      const label = 'ตกลง';
      final getFuture = await _pumpLauncher(
        tester,
        initial: ThaiAddressSelection.fromCodes(subdistrictCode: 500108),
        confirmLabel: label,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final confirm = find.text(label);
      expect(confirm, findsOneWidget);

      await tester.tap(confirm);
      await tester.pumpAndSettle();

      final result = await getFuture()!;
      expect(result, isNotNull);
      expect(result!.subdistrict?.code, 500108);
    });
  });

  group('showThaiAddressSheet — dismiss', () {
    testWidgets(
      'dismissing via the modal route resolves the future with null',
      (tester) async {
        final getFuture = await _pumpLauncher(
          tester,
          initial: ThaiAddressSelection.fromCodes(subdistrictCode: 500108),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(ThaiAddressPicker), findsOneWidget);

        // Dismiss the modal sheet the way the scrim / system-back does: pop the
        // top (modal) route with no result.
        final BuildContext sheetCtx = tester.element(
          find.byType(ThaiAddressPicker),
        );
        Navigator.of(sheetCtx).maybePop();
        await tester.pumpAndSettle();

        // The sheet is gone.
        expect(find.byType(ThaiAddressPicker), findsNothing);

        final result = await getFuture()!;
        expect(
          result,
          isNull,
          reason: 'a dismissed sheet must resolve the future with null',
        );
      },
    );
  });
}
