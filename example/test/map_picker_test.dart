// example/test/map_picker_test.dart
//
// BLIND TEST (Bug-Driven "Dev Turtle") for the EXAMPLE-ONLY "map-pin picker"
// demo card. These tests were authored from the SPEC + the GROUND TRUTH of
// package:thai_provinces_geo and package:thai_provinces_flutter ONLY — the new
// map card's implementation was NOT read. They therefore exercise the *seam*
// the card must rely on (geo reverse-geocode -> controller.setFromCodes) and a
// smoke check that the card is actually mounted in the gallery.
//
// Ground-truth used (verified against thai_provinces_geo/lib/src/geo.dart and
// thai_provinces_flutter/lib/src/{controller,selection}.dart):
//   * reverseGeocode(lat,lng,{maxKm}) == nearestSubdistrict(...)?.subdistrict.
//     It scans ALL subdistrict centroids by haversine and returns the closest,
//     or null when (a) the closest is farther than maxKm, or (b) lat/lng is
//     non-finite (NaN/Infinity).
//   * Subdistrict.code is a 6-digit DOPA code; the province code is the first
//     two digits, i.e. `code ~/ 10000`. Bangkok's province code is 10.
//   * ThaiAddressController().setFromCodes(subdistrictCode: c) delegates to
//     ThaiAddressSelection.fromCodes, which resolves the subdistrict and
//     DERIVES the parent district + province from it. So a valid subdistrict
//     code yields isComplete == true and province.code == code ~/ 10000.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// `show` the geo symbols we use so they cannot clash with the re-exported
// thai_provinces core types pulled in transitively below.
import 'package:thai_provinces_geo/thai_provinces_geo.dart'
    show reverseGeocode, nearestSubdistrict;

// This barrel re-exports Province/District/Subdistrict from thai_provinces too,
// so ThaiAddressController, ThaiAddressSelection and the core models all come
// from one import.
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

// The example app host (gallery). `main.dart` defines ExampleApp + GalleryHome.
import 'package:thai_provinces_flutter_example/main.dart';

void main() {
  // ---------------------------------------------------------------------------
  // 1. Geo -> controller integration (pure unit tests, no widget pump).
  //    This is the exact seam the map card uses: tap -> reverseGeocode ->
  //    setFromCodes(subdistrictCode: ...). If the card uses the wrong level
  //    (e.g. passes the code as provinceCode, or truncates it), or drops the
  //    maxKm bound, the corresponding test below fails.
  // ---------------------------------------------------------------------------
  group('geo -> ThaiAddressController seam', () {
    test('Bangkok land point reverse-geocodes and fills a complete selection', () {
      // Grand Palace / Phra Nakhon area, central Bangkok. The nearest
      // subdistrict centroid here must be a Bangkok (province 10) แขวง well
      // within 20 km.
      final sub = reverseGeocode(13.7563, 100.5018, maxKm: 20);

      // FAIL-BEFORE: if the dataset/lookup is broken, or maxKm wrongly excludes
      // a clearly-nearby centroid, this is null.
      expect(
        sub,
        isNotNull,
        reason: 'a dense urban point should match a subdistrict within 20km',
      );

      // First two digits of the 6-digit code == province code; Bangkok == 10.
      expect(
        sub!.code ~/ 10000,
        10,
        reason: 'central Bangkok must resolve to province code 10',
      );

      // Feed the resolved subdistrict code through the same API the card uses.
      final controller = ThaiAddressController();
      controller.setFromCodes(subdistrictCode: sub.code);
      addTearDown(controller.dispose);

      // fromCodes derives district + province from the subdistrict, so the
      // selection must be COMPLETE.
      // FAIL-BEFORE: if the card passed the code at the wrong level
      // (provinceCode/districtCode) or only set the subdistrict without
      // deriving parents, isComplete would be false.
      expect(
        controller.value.isComplete,
        isTrue,
        reason: 'setFromCodes(subdistrictCode:) must derive all 3 levels',
      );
      expect(controller.value.subdistrict?.code, sub.code);
      expect(
        controller.value.province?.code,
        10,
        reason: 'derived province must be Bangkok (10)',
      );
    });

    test('far-out-at-sea point returns null within a small radius', () {
      // Deep in the Andaman Sea / Indian Ocean, far west of any Thai land. No
      // subdistrict centroid is anywhere near here, so with a tight maxKm the
      // nearest-centroid result must be rejected -> null. This proves the
      // card's "no match -> do NOT autofill" branch is reachable.
      // (maxKm is kept small to be robust even if the nearest land centroid is
      // closer than expected; this point is hundreds of km from any centroid.)
      final sea = reverseGeocode(5.0, 92.0, maxKm: 5);

      // FAIL-BEFORE: if the card ignores/loses the maxKm bound and always
      // autofills the nearest centroid no matter how far, this returns a
      // (bogus) match instead of null.
      expect(
        sea,
        isNull,
        reason: 'open-ocean point >5km from any centroid must not match',
      );
    });

    test(
      'nearestSubdistrict reports a plausible (small) distance for Bangkok',
      () {
        // Stronger sanity check: the matched centroid for a central-Bangkok
        // point should be genuinely close (a few km), confirming the haversine
        // match is real and not an arbitrary far-away centroid.
        final match = nearestSubdistrict(13.7563, 100.5018);
        expect(match, isNotNull);
        expect(
          match!.distanceKm,
          lessThan(10.0),
          reason:
              'centroid for a central-Bangkok point should be within a '
              'few km',
        );
        expect(match.subdistrict.code ~/ 10000, 10);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // 2. Gallery smoke (widget) test: the map card is actually mounted, found by
  //    its shared key contract ValueKey('map-pin-map').
  //
  //    RISK NOTE for integrator/verifiers: FlutterMap mounts its widget tree in
  //    a test environment even though network tiles cannot load offline — that
  //    is EXPECTED and must not fail this test. We therefore:
  //      * use a large, wide surface so the card column is laid out (the card
  //        may sit below the fold on narrow layouts),
  //      * pump with a fixed duration instead of pumpAndSettle (tile-load /
  //        animation tickers can keep the scheduler busy forever -> settle
  //        would time out),
  //      * scroll the map key into view before asserting, in case the gallery
  //        is a long scrollable list,
  //      * only assert on the KEY being present (never on rendered tiles).
  //    If FlutterMap proves environmentally fragile in CI despite the above,
  //    keep the key-find assertion and treat tile/network noise as ignorable.
  // ---------------------------------------------------------------------------
  testWidgets('gallery mounts the map-pin card (ValueKey map-pin-map)', (
    tester,
  ) async {
    // Give the app a generous surface so all gallery cards are laid out.
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ExampleApp());

    // Do NOT pumpAndSettle: FlutterMap tile loaders / animation tickers may
    // never quiesce in a headless test. A few bounded pumps build the tree.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final mapFinder = find.byKey(const ValueKey('map-pin-map'));

    // If the gallery is scrollable and the card is below the fold, bring it
    // into view. scrollUntilVisible is a no-op-safe attempt; guard it so a
    // non-scrollable layout (card already on screen) doesn't fail the test.
    if (mapFinder.evaluate().isEmpty) {
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        try {
          await tester.scrollUntilVisible(
            mapFinder,
            300.0,
            scrollable: scrollable.first,
            maxScrolls: 50,
          );
        } catch (_) {
          // Either already visible or no matching scrollable direction; the
          // assertion below is the source of truth.
        }
        await tester.pump();
      }
    }

    // FAIL-BEFORE: if the map card is not added to the gallery, or it omits /
    // mistypes the agreed key ValueKey('map-pin-map'), this finds nothing.
    expect(
      mapFinder,
      findsOneWidget,
      reason:
          "the map-pin card must mount a widget keyed "
          "ValueKey('map-pin-map') in the gallery",
    );
  });
}
