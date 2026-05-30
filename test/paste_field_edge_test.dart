// Blind config + lifecycle edge tests for [ThaiAddressPasteField].
//
// Written against the public contract only (the barrel + thai_provinces public
// API), without reading lib/src/paste_field.dart. Covers TEST A (1–5):
//   1. enabled:false disables confirm and commits nothing even with a valid
//      parse.
//   2. language:english renders English labels.
//   3. custom decoration / hintText is passed through to the TextField.
//   4. controller swap via didUpdateWidget commits to the NEW controller, and
//      null<->provided transitions do not throw.
//   5. onParsed (full parse: remainder/postcode) and onChanged (committed
//      selection) both fire on a confirm.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

// A real Bangkok address that resolves a full province/district/subdistrict
// chain: province 10 (กรุงเทพมหานคร), postcode 10200, remainder keeps '123/45'.
const String _bangkokAddress =
    '123/45 ถ.สุขุมวิท แขวงคลองเตย เขตคลองเตย กรุงเทพฯ 10200';

// Province code of Bangkok.
const int _bangkokProvinceCode = 10;

// Input + confirm keys per the contract.
final Key _inputKey = const ValueKey('paste-input');
final Key _confirmKey = const ValueKey('paste-confirm');

// Garbage that recognises nothing administrative.
const String _garbage = 'zzz qqq not an address 99999999';

Finder get _confirm => find.byKey(_confirmKey);

/// Pumps a [ThaiAddressPasteField] inside a MaterialApp/Scaffold.
Future<void> _pumpField(
  WidgetTester tester, {
  required ThaiAddressController controller,
  bool enabled = true,
  ThaiAddressLanguage language = ThaiAddressLanguage.thai,
  InputDecoration? decoration,
  String? hintText,
  ValueChanged<ThaiAddressParseResult>? onParsed,
  ValueChanged<ThaiAddressSelection?>? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ThaiAddressPasteField(
          controller: controller,
          enabled: enabled,
          language: language,
          decoration: decoration,
          hintText: hintText,
          onParsed: onParsed,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

/// Enters [text] into the paste input and settles the preview.
Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(_inputKey), text);
  await tester.pumpAndSettle();
}

void main() {
  group('ThaiAddressPasteField — config + lifecycle edges', () {
    testWidgets(
      '1. enabled:false disables confirm and commits nothing for a valid parse',
      (tester) async {
        final controller = ThaiAddressController();
        addTearDown(controller.dispose);

        await _pumpField(tester, controller: controller, enabled: false);
        await _type(tester, _bangkokAddress);

        // Confirm must be disabled even though the address parses fully.
        final button = tester.widget<FilledButton>(_confirm);
        expect(
          button.onPressed,
          isNull,
          reason: 'enabled:false must disable the confirm button',
        );

        // Tapping a disabled button does nothing; the controller stays empty.
        await tester.tap(_confirm, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(
          controller.value.isEmpty,
          isTrue,
          reason: 'a disabled field must never commit',
        );
        expect(controller.province, isNull);
      },
    );

    testWidgets('2. language:english renders English labels', (tester) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      await _pumpField(
        tester,
        controller: controller,
        language: ThaiAddressLanguage.english,
      );

      // A valid parse → the English confirm label.
      await _type(tester, _bangkokAddress);
      expect(
        find.text('Use this address'),
        findsOneWidget,
        reason: 'english confirm label',
      );

      // Garbage → the English "couldn't recognize" hint.
      await _type(tester, _garbage);
      expect(
        find.textContaining("Couldn't recognize"),
        findsOneWidget,
        reason: 'english not-recognised hint',
      );
    });

    testWidgets('3. custom decoration / hintText passes through to the input', (
      tester,
    ) async {
      final controller = ThaiAddressController();
      addTearDown(controller.dispose);

      // 3a. A caller-supplied decoration is respected (its hintText shows).
      await _pumpField(
        tester,
        controller: controller,
        decoration: const InputDecoration(hintText: 'paste your address here'),
      );
      final field1 = tester.widget<TextField>(find.byKey(_inputKey));
      expect(
        field1.decoration?.hintText,
        'paste your address here',
        reason: 'caller decoration must be respected',
      );

      // 3b. A caller hintText (no decoration) fills the hint.
      await _pumpField(
        tester,
        controller: controller,
        hintText: 'my hint text',
      );
      final field2 = tester.widget<TextField>(find.byKey(_inputKey));
      expect(
        field2.decoration?.hintText,
        'my hint text',
        reason: 'caller hintText must reach the input',
      );
      expect(find.text('my hint text'), findsOneWidget);
    });

    testWidgets(
      '4. controller swap commits to the NEW controller; A untouched',
      (tester) async {
        final controllerA = ThaiAddressController();
        final controllerB = ThaiAddressController();
        addTearDown(controllerA.dispose);
        addTearDown(controllerB.dispose);

        final useB = ValueNotifier<bool>(false);
        addTearDown(useB.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _SwapHarness(
                controllerA: controllerA,
                controllerB: controllerB,
                useB: useB,
              ),
            ),
          ),
        );

        // Type a valid address under controller A (no commit yet).
        await _type(tester, _bangkokAddress);
        expect(controllerA.value.isEmpty, isTrue);
        expect(controllerB.value.isEmpty, isTrue);

        // Swap to controller B via didUpdateWidget, then re-type and confirm.
        useB.value = true;
        await tester.pumpAndSettle();
        await _type(tester, _bangkokAddress);
        await tester.tap(_confirm);
        await tester.pumpAndSettle();

        // The commit landed on B, and A was never touched.
        expect(
          controllerB.province?.code,
          _bangkokProvinceCode,
          reason: 'commit must land on the swapped-in controller B',
        );
        expect(
          controllerA.value.isEmpty,
          isTrue,
          reason: 'the detached controller A must be untouched',
        );
      },
    );

    testWidgets('4b. null<->provided controller swaps do not throw', (
      tester,
    ) async {
      final provided = ThaiAddressController();
      addTearDown(provided.dispose);

      final supply = ValueNotifier<bool>(false);
      addTearDown(supply.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _NullableSwapHarness(controller: provided, supply: supply),
          ),
        ),
      );

      // null -> provided.
      supply.value = true;
      await tester.pumpAndSettle();
      // provided -> null.
      supply.value = false;
      await tester.pumpAndSettle();
      // ...and back again for good measure.
      supply.value = true;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The internally-owned controller (null case) still works enough to build.
      expect(find.byKey(_inputKey), findsOneWidget);
    });

    testWidgets(
      '5. onParsed gets full parse (remainder/postcode); onChanged the selection',
      (tester) async {
        final controller = ThaiAddressController();
        addTearDown(controller.dispose);

        ThaiAddressParseResult? parsed;
        ThaiAddressSelection? changed;

        await _pumpField(
          tester,
          controller: controller,
          onParsed: (r) => parsed = r,
          onChanged: (s) => changed = s,
        );

        await _type(tester, _bangkokAddress);
        await tester.tap(_confirm);
        await tester.pumpAndSettle();

        // onParsed = the raw best-effort parse, incl. remainder + postcode.
        expect(parsed, isNotNull, reason: 'onParsed must fire on confirm');
        expect(parsed!.province?.code, _bangkokProvinceCode);
        expect(parsed!.postcode, 10200);
        expect(
          parsed!.remainder,
          contains('123/45'),
          reason: 'onParsed.remainder keeps the un-attributed house number',
        );

        // onChanged = the committed selection (mirrors the controller value).
        expect(changed, isNotNull, reason: 'onChanged must fire on confirm');
        expect(changed!.province?.code, _bangkokProvinceCode);
        expect(
          changed,
          controller.value,
          reason: 'onChanged delivers the committed controller value',
        );
        expect(controller.province?.code, _bangkokProvinceCode);
      },
    );
  });
}

/// A wrapper that swaps which non-null controller the paste field uses, so the
/// field's [State.didUpdateWidget] re-runs with a different controller.
class _SwapHarness extends StatefulWidget {
  const _SwapHarness({
    required this.controllerA,
    required this.controllerB,
    required this.useB,
  });

  final ThaiAddressController controllerA;
  final ThaiAddressController controllerB;
  final ValueNotifier<bool> useB;

  @override
  State<_SwapHarness> createState() => _SwapHarnessState();
}

class _SwapHarnessState extends State<_SwapHarness> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.useB,
      builder: (context, useB, _) {
        return ThaiAddressPasteField(
          controller: useB ? widget.controllerB : widget.controllerA,
        );
      },
    );
  }
}

/// A wrapper that toggles between a provided controller and `null` (the field
/// owning its own controller internally), to exercise both didUpdateWidget
/// transitions without throwing.
class _NullableSwapHarness extends StatefulWidget {
  const _NullableSwapHarness({required this.controller, required this.supply});

  final ThaiAddressController controller;
  final ValueNotifier<bool> supply;

  @override
  State<_NullableSwapHarness> createState() => _NullableSwapHarnessState();
}

class _NullableSwapHarnessState extends State<_NullableSwapHarness> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.supply,
      builder: (context, supply, _) {
        return ThaiAddressPasteField(
          controller: supply ? widget.controller : null,
        );
      },
    );
  }
}
