// BLIND TEST (Tester A) for showThaiAddressSearch — written FROM SPEC ONLY.
//
// The search.dart implementation was NOT read; these tests are derived purely
// from the contract:
//
//   Future<ThaiAddressSelection?> showThaiAddressSearch(
//     BuildContext context, {
//     ThaiAddressLanguage language = ThaiAddressLanguage.thai,
//     String? searchHint,
//   })
//
// Spec: a FULL-SCREEN search address picker, implemented with a private
// SearchDelegate. It shows a search UI (a TextField in an AppBar). Typing a
// query surfaces ranked result tiles whose label is the suggestion breadcrumb
// (ThaiAddressSuggestion.display(language)). Tapping a result tile resolves the
// future with that suggestion's selection. Dismissing via the leading
// back/close affordance resolves the future with null.
//
// Test data (DOPA codes, cross-checked against the embedded dataset's
// suggestion engine in this test file's sibling tooling):
//   query 'สุเทพ' -> exactly one suggestion:
//     breadcrumb 'ตำบลสุเทพ อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่ 50200'
//     province.code == 50, subdistrict.code == 500108.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

/// Pumps a MaterialApp with a single button that, when tapped, opens the
/// search and stashes the returned future for the test to await.
///
/// Returns a getter yielding the captured future (null until the button has
/// been tapped).
Future<Future<ThaiAddressSelection?>? Function()> _pumpLauncher(
  WidgetTester tester, {
  ThaiAddressLanguage language = ThaiAddressLanguage.thai,
  String? searchHint,
}) async {
  Future<ThaiAddressSelection?>? future;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              future = showThaiAddressSearch(
                context,
                language: language,
                searchHint: searchHint,
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

/// The single search-bar [TextField] of the open search UI.
Finder get _searchField => find.byType(TextField);

void main() {
  group('showThaiAddressSearch — opens', () {
    testWidgets('shows a search field (TextField in an AppBar)', (
      tester,
    ) async {
      await _pumpLauncher(tester);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // A search UI is shown: a TextField search bar that lives in an AppBar.
      expect(
        _searchField,
        findsOneWidget,
        reason: 'the search UI must present a single TextField search bar',
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
        reason: 'the search field must be hosted in an AppBar',
      );

      // It must be typeable: entering text does not throw and is reflected.
      await tester.enterText(_searchField, 'ก');
      await tester.pumpAndSettle();
      expect(find.text('ก'), findsWidgets);
    });
  });

  group('showThaiAddressSearch — type & pick', () {
    testWidgets(
      'typing สุเทพ surfaces a breadcrumb result; tapping it resolves '
      'province 50 / subdistrict 500108',
      (tester) async {
        final getFuture = await _pumpLauncher(tester);

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final future = getFuture();
        expect(future, isNotNull, reason: 'the launcher captured no future');

        // Type the query into the search bar.
        await tester.enterText(_searchField, 'สุเทพ');
        await tester.pumpAndSettle();

        // At least one result tile shows a breadcrumb containing 'สุเทพ'.
        expect(
          find.textContaining('สุเทพ'),
          findsWidgets,
          reason: 'a result tile breadcrumb containing สุเทพ must appear',
        );

        // Locate the result whose breadcrumb names both สุเทพ and เชียงใหม่.
        // (The Chiang Mai สุเทพ subdistrict, code 500108, province 50.)
        final result = find.textContaining('สุเทพ').evaluate().where((e) {
          final text = (e.widget as Text).data ?? '';
          return text.contains('สุเทพ') && text.contains('เชียงใหม่');
        });
        expect(
          result,
          isNotEmpty,
          reason: 'expected a สุเทพ/เชียงใหม่ breadcrumb result tile',
        );

        // Tap that tile.
        await tester.tap(find.text((result.first.widget as Text).data!));
        await tester.pumpAndSettle();

        // The future resolves to the picked selection.
        final selection = await future!;
        expect(selection, isNotNull, reason: 'picking must resolve non-null');
        expect(selection!.province?.code, 50);
        expect(selection.subdistrict?.code, 500108);
      },
    );
  });

  group('showThaiAddressSearch — dismiss', () {
    testWidgets(
      'tapping the leading back affordance resolves the future with null',
      (tester) async {
        final getFuture = await _pumpLauncher(tester);

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // The search UI is up.
        expect(_searchField, findsOneWidget);

        // Tap the leading back/close affordance. A SearchDelegate's default
        // leading is a back button (tooltip 'Back' / BackButton). Try the most
        // specific finders first, then fall back to the AppBar's leading
        // IconButton.
        final byTooltip = find.byTooltip('Back');
        final byType = find.byType(BackButton);
        final Finder back;
        if (byTooltip.evaluate().isNotEmpty) {
          back = byTooltip;
        } else if (byType.evaluate().isNotEmpty) {
          back = byType;
        } else {
          back = find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(IconButton),
          );
        }
        expect(
          back,
          findsWidgets,
          reason: 'a leading back/close affordance must be present',
        );

        await tester.tap(back.first);
        await tester.pumpAndSettle();

        // The search UI is gone.
        expect(_searchField, findsNothing);

        final selection = await getFuture()!;
        expect(
          selection,
          isNull,
          reason: 'a dismissed search must resolve the future with null',
        );
      },
    );
  });
}
