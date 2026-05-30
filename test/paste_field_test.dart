// test/paste_field_test.dart
//
// BLIND test suite for ThaiAddressPasteField, authored from the public API
// contract + key contract only (the widget implementation in
// lib/src/paste_field.dart was NOT read).
//
// Ground-truth expected values were derived from the real parser
// (thaiaddress-dart/lib/src/parse.dart) and the controller/selection contracts
// (lib/src/controller.dart, lib/src/selection.dart):
//
//  * Bangkok input
//    '123/45 ถนนหน้าพระลาน แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร 10200'
//      - Bangkok alias 'กรุงเทพมหานคร' -> province code 10.
//      - district marker 'เขต' + name 'พระนคร'        -> district code 1001.
//      - subdistrict marker 'แขวง' + 'พระบรมมหาราชวัง' -> subdistrict 100101.
//      - first valid 5-digit run '10200'             -> postcode 10200.
//      - '123/45' is unmarked free text and survives in the remainder
//        ('ถนนหน้าพระลาน' survives too; no area marker consumes it).
//      => result.isComplete, province 10 / district 1001 / sub 100101,
//         postcode 10200, remainder contains '123/45'.
//
//  * Chiang Mai input
//    '99 หมู่ 2 ตำบลสุเทพ อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่ 50200'
//      - 'จังหวัดเชียงใหม่'        -> province code 50.
//      - 'อำเภอเมืองเชียงใหม่'     -> district code 5001.
//      - 'ตำบลสุเทพ'              -> subdistrict code 500108.
//      - '50200'                  -> postcode 50200.
//      => result.isComplete, province 50 / sub 500108.
//
//  * Garbage 'hello world' -> parser never throws; no markers, no valid
//    postcode -> result.isEmpty is true (province/district/subdistrict/postcode
//    all null). So confirm must be disabled and nothing commits.
//
// Behavior contract relied on (NOT the implementation):
//  - Typing/pasting parses live and previews, but DOES NOT commit to the
//    controller. Only tapping the confirm button commits via
//    controller.setFromCodes(...) from the parsed codes, then fires
//    onParsed(result) and onChanged(selection).
//  - Keys: paste TextField = ValueKey('paste-input'),
//          confirm button   = ValueKey('paste-confirm') (enabled only when a
//          province was recognised).
//  - Garbage -> confirm disabled / no commit / no crash.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

/// A full Bangkok address that the parser resolves completely (see header).
const String _bangkok =
    '123/45 ถนนหน้าพระลาน แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร 10200';

/// A full Chiang Mai address that the parser resolves completely (see header).
const String _chiangMai =
    '99 หมู่ 2 ตำบลสุเทพ อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่ 50200';

const Key _inputKey = ValueKey('paste-input');
const Key _confirmKey = ValueKey('paste-confirm');

/// Pumps a [ThaiAddressPasteField] wired to [controller] inside a minimal
/// MaterialApp/Scaffold, plus optional callbacks.
Future<void> _pumpField(
  WidgetTester tester, {
  ThaiAddressController? controller,
  void Function(ThaiAddressParseResult)? onParsed,
  ValueChanged<ThaiAddressSelection?>? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ThaiAddressPasteField(
          controller: controller,
          onParsed: onParsed,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

void main() {
  group('ThaiAddressPasteField', () {
    // -----------------------------------------------------------------------
    // Test 1 — No commit before confirm.
    // FAIL-BEFORE: an implementation that commits on type (auto-commit) would
    // leave c.value non-empty here, violating "confirm is never silent".
    // -----------------------------------------------------------------------
    testWidgets('typing does not commit to the controller before confirm', (
      tester,
    ) async {
      final c = ThaiAddressController();
      addTearDown(c.dispose);

      await _pumpField(tester, controller: c);

      // Sanity: starts empty.
      expect(c.value.isEmpty, isTrue);

      await tester.enterText(find.byKey(_inputKey), _bangkok);
      await tester.pump();

      // Parsing/preview must NOT have touched the controller.
      expect(
        c.value.isEmpty,
        isTrue,
        reason: 'typing must preview only; commit happens on confirm',
      );
      expect(tester.takeException(), isNull);
    });

    // -----------------------------------------------------------------------
    // Test 2 — Confirm commits the parsed chain and fires both callbacks.
    // FAIL-BEFORE: a confirm that doesn't commit (controller stays empty),
    // commits the wrong codes, or fails to fire onParsed/onChanged.
    // -----------------------------------------------------------------------
    testWidgets('confirm commits the Bangkok chain and fires callbacks', (
      tester,
    ) async {
      final c = ThaiAddressController();
      addTearDown(c.dispose);

      ThaiAddressParseResult? parsed;
      ThaiAddressSelection? changed;

      await _pumpField(
        tester,
        controller: c,
        onParsed: (r) => parsed = r,
        onChanged: (s) => changed = s,
      );

      await tester.enterText(find.byKey(_inputKey), _bangkok);
      await tester.pump();

      // Confirm should be enabled now (a province was recognised).
      final btn = tester.widget<ButtonStyleButton>(find.byKey(_confirmKey));
      expect(
        btn.onPressed,
        isNotNull,
        reason: 'a recognised province must enable confirm',
      );

      await tester.tap(find.byKey(_confirmKey));
      await tester.pump();

      // Controller now holds the full, internally-consistent chain.
      expect(c.value.isComplete, isTrue);
      expect(c.value.province?.code, 10);
      expect(c.value.district?.code, 1001);
      expect(c.value.subdistrict?.code, 100101);

      // onChanged fired with the committed selection.
      expect(changed, isNotNull);
      expect(changed!.province?.code, 10);
      expect(changed!.subdistrict?.code, 100101);
      expect(changed!.isComplete, isTrue);

      // onParsed fired with the raw parse result (postcode + remainder intact).
      expect(parsed, isNotNull);
      expect(parsed!.postcode, 10200);
      expect(parsed!.remainder, contains('123/45'));

      expect(tester.takeException(), isNull);
    });

    // -----------------------------------------------------------------------
    // Test 3 — Preview shows recognised info before confirm.
    // FAIL-BEFORE: a widget that parses but renders no preview (the province
    // name never appears on screen pre-confirm).
    // -----------------------------------------------------------------------
    testWidgets(
      'shows recognised province name in the preview before confirm',
      (tester) async {
        final c = ThaiAddressController();
        addTearDown(c.dispose);

        await _pumpField(tester, controller: c);

        await tester.enterText(find.byKey(_inputKey), _bangkok);
        await tester.pump();

        // The recognised Bangkok province name should be shown somewhere.
        expect(
          find.textContaining('กรุงเทพมหานคร'),
          findsWidgets,
          reason: 'recognised province must be previewed before confirm',
        );

        // And it must still not have committed (preview != commit).
        expect(c.value.isEmpty, isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // Test 4 — Garbage: confirm disabled, no commit, no crash.
    // FAIL-BEFORE: a widget that enables confirm / commits garbage / throws on
    // unrecognised input.
    // -----------------------------------------------------------------------
    testWidgets('garbage input leaves confirm disabled and commits nothing', (
      tester,
    ) async {
      final c = ThaiAddressController();
      addTearDown(c.dispose);

      await _pumpField(tester, controller: c);

      await tester.enterText(find.byKey(_inputKey), 'hello world');
      await tester.pump();

      // The confirm button should be present but disabled.
      final btn = tester.widget<ButtonStyleButton>(find.byKey(_confirmKey));
      expect(
        btn.onPressed,
        isNull,
        reason: 'unrecognised input must keep confirm disabled',
      );

      // Even attempting a tap must not commit anything or crash.
      await tester.tap(find.byKey(_confirmKey), warnIfMissed: false);
      await tester.pump();

      expect(c.value.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });

    // -----------------------------------------------------------------------
    // Test 4b — A multi-province postcode (province unresolved) keeps confirm
    // disabled even though a postcode WAS recognized (result is not isEmpty).
    // FAIL-BEFORE: gating confirm on !isEmpty (instead of province != null)
    // would enable it for '13240' and commit an empty/useless selection.
    // -----------------------------------------------------------------------
    testWidgets('multi-province postcode keeps confirm disabled, no commit', (
      tester,
    ) async {
      final c = ThaiAddressController();
      addTearDown(c.dispose);

      await _pumpField(tester, controller: c);

      // 13240 spans multiple provinces -> parser sets the postcode but cannot
      // pin a province (verified against the parser/dataset).
      await tester.enterText(find.byKey(_inputKey), '13240');
      await tester.pump();

      final btn = tester.widget<ButtonStyleButton>(find.byKey(_confirmKey));
      expect(
        btn.onPressed,
        isNull,
        reason: 'a postcode with no resolved province must not enable confirm',
      );

      await tester.tap(find.byKey(_confirmKey), warnIfMissed: false);
      await tester.pump();
      expect(c.value.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });

    // -----------------------------------------------------------------------
    // Test 5 — Second distinct case (Chiang Mai) so test 2 isn't a one-off.
    // FAIL-BEFORE: codes hard-coded to Bangkok, or a parser/commit path that
    // only works for the capital.
    // -----------------------------------------------------------------------
    testWidgets('confirm commits the Chiang Mai chain', (tester) async {
      final c = ThaiAddressController();
      addTearDown(c.dispose);

      await _pumpField(tester, controller: c);

      await tester.enterText(find.byKey(_inputKey), _chiangMai);
      await tester.pump();

      final btn = tester.widget<ButtonStyleButton>(find.byKey(_confirmKey));
      expect(btn.onPressed, isNotNull);

      await tester.tap(find.byKey(_confirmKey));
      await tester.pump();

      expect(c.value.isComplete, isTrue);
      expect(c.value.province?.code, 50);
      expect(c.value.subdistrict?.code, 500108);
      expect(tester.takeException(), isNull);
    });

    // -----------------------------------------------------------------------
    // Test 6 — Null controller: the widget owns one internally.
    // FAIL-BEFORE: a widget that assumes a non-null controller and throws when
    // none is supplied.
    // -----------------------------------------------------------------------
    testWidgets('pumps without a supplied controller (owns one internally)', (
      tester,
    ) async {
      await _pumpField(tester); // controller == null

      expect(tester.takeException(), isNull);
      expect(find.byKey(_inputKey), findsOneWidget);
      expect(find.byKey(_confirmKey), findsOneWidget);

      // Typing into the internally-owned controller should not throw, and the
      // confirm button should enable for a recognised address.
      await tester.enterText(find.byKey(_inputKey), _bangkok);
      await tester.pump();

      final btn = tester.widget<ButtonStyleButton>(find.byKey(_confirmKey));
      expect(btn.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
}
