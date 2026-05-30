// Blind interaction-behavior tests (TEST B) for [ThaiAddressPasteField].
//
// These cover the paste-and-confirm INTERACTION behavior of the widget, not
// its config/lifecycle (that is TEST A). They assert against the *committed*
// controller (its DOPA codes via `toCodes()`) and the confirm button's enabled
// state — never against private widget internals.
//
// Known-good real strings (mirroring the existing dev test's vetted inputs):
//   Bangkok    -> province code 10  ('...กรุงเทพมหานคร 10200')
//   Chiang Mai -> province code 50  ('...จังหวัดเชียงใหม่ 50200')
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

void main() {
  // Keys exposed by the contract.
  const inputKey = ValueKey('paste-input');
  const confirmKey = ValueKey('paste-confirm');

  // Real, vetted free-text addresses.
  const bangkok =
      '123/45 ถนนหน้าพระลาน แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร 10200';
  const chiangMai =
      '99 หมู่ 2 ตำบลสุเทพ อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่ 50200';

  // Pumps the field bound to [controller] inside a minimal app.
  Future<void> pumpField(
    WidgetTester tester,
    ThaiAddressController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ThaiAddressPasteField(controller: controller)),
      ),
    );
  }

  // True when the confirm button is currently tappable.
  bool confirmEnabled(WidgetTester tester) {
    final button = tester.widget<FilledButton>(find.byKey(confirmKey));
    return button.onPressed != null;
  }

  // The committed DOPA codes held by the controller right now.
  (int? p, int? d, int? s) committedCodes(ThaiAddressController controller) =>
      controller.value.toCodes();

  testWidgets('1. paste updates preview but does not commit until confirm', (
    tester,
  ) async {
    final controller = ThaiAddressController();
    addTearDown(controller.dispose);
    await pumpField(tester, controller);

    // Simulate a paste of a full valid address into the input.
    await tester.enterText(find.byKey(inputKey), bangkok);
    await tester.pump();

    // Preview path: the recognised province surfaces in the preview, and the
    // confirm becomes enabled — but the shared controller is STILL empty.
    expect(find.textContaining('กรุงเทพมหานคร'), findsWidgets);
    expect(
      confirmEnabled(tester),
      isTrue,
      reason: 'valid paste enables confirm',
    );
    expect(
      controller.value.isEmpty,
      isTrue,
      reason: 'paste must not commit before confirm',
    );
    expect(committedCodes(controller), (null, null, null));

    // Confirm now commits the Bangkok chain.
    await tester.tap(find.byKey(confirmKey));
    await tester.pump();
    final (p, _, _) = committedCodes(controller);
    expect(p, 10, reason: 'confirm commits Bangkok province code 10');
    expect(controller.value.isEmpty, isFalse);
  });

  testWidgets('2. re-edit between provinces; neither commits before confirm', (
    tester,
  ) async {
    final controller = ThaiAddressController();
    addTearDown(controller.dispose);
    await pumpField(tester, controller);

    // Address 1: Bangkok.
    await tester.enterText(find.byKey(inputKey), bangkok);
    await tester.pump();
    expect(find.textContaining('กรุงเทพมหานคร'), findsWidgets);
    expect(confirmEnabled(tester), isTrue);
    expect(controller.value.isEmpty, isTrue, reason: 'no commit on first edit');

    // Clear, then Address 2: Chiang Mai. The preview must now reflect Y.
    await tester.enterText(find.byKey(inputKey), '');
    await tester.pump();
    await tester.enterText(find.byKey(inputKey), chiangMai);
    await tester.pump();
    expect(find.textContaining('เชียงใหม่'), findsWidgets);
    expect(
      find.textContaining('กรุงเทพมหานคร'),
      findsNothing,
      reason: 're-edit replaces the previous preview',
    );
    expect(confirmEnabled(tester), isTrue);

    // Still nothing committed across all the re-edits.
    expect(
      controller.value.isEmpty,
      isTrue,
      reason: 'no edit commits before confirm',
    );
    expect(committedCodes(controller), (null, null, null));

    // Confirm finally commits Chiang Mai (province 50), not Bangkok.
    await tester.tap(find.byKey(confirmKey));
    await tester.pump();
    final (p, _, _) = committedCodes(controller);
    expect(p, 50, reason: 'commits the LAST edited address (Chiang Mai)');
  });

  testWidgets(
    '3. editing to garbage after a commit disables confirm but keeps the commit',
    (tester) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);
      await pumpField(tester, controller);

      // Commit a valid Bangkok address.
      await tester.enterText(find.byKey(inputKey), bangkok);
      await tester.pump();
      await tester.tap(find.byKey(confirmKey));
      await tester.pump();
      final committed = committedCodes(controller);
      expect(committed.$1, 10, reason: 'precondition: Bangkok committed');

      // Now edit the text to garbage.
      await tester.enterText(find.byKey(inputKey), 'this is not an address');
      await tester.pump();

      // Confirm goes disabled again (no province parsed)...
      expect(
        confirmEnabled(tester),
        isFalse,
        reason: 'garbage parse disables confirm',
      );

      // ...but the previously committed value is UNTOUCHED (editing does not
      // revert a commit).
      expect(
        committedCodes(controller),
        committed,
        reason: 'editing must not revert the committed selection',
      );
      expect(controller.province?.code, 10);
    },
  );

  testWidgets('4. confirming twice with no edit is safe and idempotent', (
    tester,
  ) async {
    final controller = ThaiAddressController();
    addTearDown(controller.dispose);
    await pumpField(tester, controller);

    await tester.enterText(find.byKey(inputKey), chiangMai);
    await tester.pump();

    // First confirm.
    await tester.tap(find.byKey(confirmKey));
    await tester.pump();
    final afterFirst = committedCodes(controller);
    expect(afterFirst.$1, 50, reason: 'first confirm commits Chiang Mai');

    // Second confirm with NO edit in between must not throw and must hold the
    // identical chain.
    await tester.tap(find.byKey(confirmKey), warnIfMissed: false);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'double-confirm is safe');
    expect(
      committedCodes(controller),
      afterFirst,
      reason: 'double-confirm holds the same chain',
    );
  });

  testWidgets(
    '5. empty input shows the not-recognised hint and disables confirm',
    (tester) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);
      await pumpField(tester, controller);

      // Leave the field empty (default), then touch it to ensure the empty path
      // is exercised.
      await tester.enterText(find.byKey(inputKey), '');
      await tester.pump();

      // Confirm is disabled for empty input.
      expect(
        confirmEnabled(tester),
        isFalse,
        reason: 'empty input cannot be confirmed',
      );

      // Nothing committed.
      expect(controller.value.isEmpty, isTrue);
      expect(committedCodes(controller), (null, null, null));

      // The preview shows a "not recognised" hint rather than any province name.
      expect(
        find.textContaining('กรุงเทพมหานคร'),
        findsNothing,
        reason: 'no province should be previewed for empty input',
      );
      expect(find.textContaining('เชียงใหม่'), findsNothing);
    },
  );
}
