import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

/// Bangkok (code 10) is a stable, well-known province with many districts and
/// subdistricts, so it makes a reliable fixture.
Province get _bangkok => provinceByCode(10)!;

/// A second, different province for cascade-clear tests.
Province get _otherProvince => provinces().firstWhere((p) => p.code != 10);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

DropdownButtonFormField<T> _dropdown<T>(WidgetTester tester, Key key) =>
    tester.widget<DropdownButtonFormField<T>>(find.byKey(key));

/// Reads the option values from the inner [DropdownButton] of a keyed
/// [DropdownButtonFormField]. ([DropdownButtonFormField] does not expose
/// `items` directly.)
List<T?> _dropdownValues<T>(WidgetTester tester, Key key) {
  final button = tester.widget<DropdownButton<T>>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byType(DropdownButton<T>),
    ),
  );
  return button.items!.map((i) => i.value).toList();
}

void main() {
  const provinceKey = Key('thaiAddress.province');
  const districtKey = Key('thaiAddress.district');
  const subdistrictKey = Key('thaiAddress.subdistrict');
  const postcodeKey = Key('thaiAddress.postcode');

  testWidgets('only the province dropdown is enabled initially', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ThaiAddressPicker()));

    expect(
      _dropdown<Province>(tester, provinceKey).onChanged,
      isNotNull,
      reason: 'province should be enabled',
    );
    expect(
      _dropdown<District>(tester, districtKey).onChanged,
      isNull,
      reason: 'district should be disabled until a province is chosen',
    );
    expect(
      _dropdown<Subdistrict>(tester, subdistrictKey).onChanged,
      isNull,
      reason: 'subdistrict should be disabled until a district is chosen',
    );
  });

  testWidgets('cascading selection enables children and fills postcode', (
    tester,
  ) async {
    final controller = ThaiAddressController();
    addTearDown(controller.dispose);

    final changes = <ThaiAddressSelection>[];

    await tester.pumpWidget(
      _wrap(ThaiAddressPicker(controller: controller, onChanged: changes.add)),
    );

    // Pick a province.
    final province = _bangkok;
    controller.setProvince(province);
    await tester.pump();

    final districtField = _dropdown<District>(tester, districtKey);
    expect(
      districtField.onChanged,
      isNotNull,
      reason: 'district enabled after province chosen',
    );
    expect(
      _dropdownValues<District>(tester, districtKey),
      equals(province.districts),
      reason: 'district items are exactly this province\'s districts',
    );
    expect(_dropdown<Subdistrict>(tester, subdistrictKey).onChanged, isNull);

    // Pick a district.
    final district = province.districts.first;
    controller.setDistrict(district);
    await tester.pump();

    final subdistrictField = _dropdown<Subdistrict>(tester, subdistrictKey);
    expect(
      subdistrictField.onChanged,
      isNotNull,
      reason: 'subdistrict enabled after district chosen',
    );
    expect(
      _dropdownValues<Subdistrict>(tester, subdistrictKey),
      equals(district.subdistricts),
    );

    // Pick a subdistrict -> postcode fills, onChanged fired complete.
    final subdistrict = district.subdistricts.first;
    controller.setSubdistrict(subdistrict);
    await tester.pump();

    expect(controller.value.isComplete, isTrue);
    expect(controller.value.postcode, equals(subdistrict.postcode));

    final postcodeField = tester.widget<TextField>(find.byKey(postcodeKey));
    expect(postcodeField.controller!.text, equals('${subdistrict.postcode}'));

    expect(changes, isNotEmpty);
    expect(
      changes.last.isComplete,
      isTrue,
      reason: 'onChanged fired with a complete selection',
    );
    expect(changes.last.postcode, equals(subdistrict.postcode));
  });

  testWidgets('setProvince to a different province cascade-clears children', (
    tester,
  ) async {
    final controller = ThaiAddressController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(ThaiAddressPicker(controller: controller)));

    // Build a complete selection in Bangkok.
    final province = _bangkok;
    final district = province.districts.first;
    final subdistrict = district.subdistricts.first;
    controller
      ..setProvince(province)
      ..setDistrict(district)
      ..setSubdistrict(subdistrict);
    await tester.pump();
    expect(controller.value.isComplete, isTrue);

    // Switch to a different province -> children + postcode cleared.
    controller.setProvince(_otherProvince);
    await tester.pump();

    expect(controller.value.province, equals(_otherProvince));
    expect(controller.value.district, isNull);
    expect(controller.value.subdistrict, isNull);
    expect(controller.value.postcode, isNull);

    expect(
      _dropdown<Subdistrict>(tester, subdistrictKey).onChanged,
      isNull,
      reason: 'subdistrict disabled again after province change',
    );

    final postcodeField = tester.widget<TextField>(find.byKey(postcodeKey));
    expect(postcodeField.controller!.text, isEmpty);
  });

  test('controller guards reject cross-parent values', () {
    final controller = ThaiAddressController();
    addTearDown(controller.dispose);

    final bangkok = _bangkok;
    final other = _otherProvince;
    controller.setProvince(bangkok);

    // A district from a different province is ignored (asserts in debug, so
    // wrap in a debug-tolerant expectation).
    final foreignDistrict = other.districts.first;
    expect(() => controller.setDistrict(foreignDistrict), throwsAssertionError);
    expect(
      controller.value.district,
      isNull,
      reason: 'foreign district not applied',
    );

    // A valid district then a foreign subdistrict.
    final district = bangkok.districts.first;
    controller.setDistrict(district);
    final foreignSub = other.districts.first.subdistricts.first;
    expect(() => controller.setSubdistrict(foreignSub), throwsAssertionError);
    expect(
      controller.value.subdistrict,
      isNull,
      reason: 'foreign subdistrict not applied',
    );
  });

  testWidgets('ThaiAddressFormField validates isComplete', (tester) async {
    final formKey = GlobalKey<FormState>();
    final controller = ThaiAddressController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        Form(
          key: formKey,
          child: ThaiAddressFormField(
            controller: controller,
            validator: (sel) =>
                (sel != null && sel.isComplete) ? null : 'Address incomplete',
          ),
        ),
      ),
    );

    // Incomplete -> invalid + error shown.
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Address incomplete'), findsOneWidget);

    // Complete the selection through the controller.
    final province = _bangkok;
    final district = province.districts.first;
    final subdistrict = district.subdistricts.first;
    controller
      ..setProvince(province)
      ..setDistrict(district)
      ..setSubdistrict(subdistrict);
    await tester.pump();

    expect(formKey.currentState!.validate(), isTrue);
    await tester.pump();
    expect(find.text('Address incomplete'), findsNothing);
  });

  test('ThaiAddressSelection JSON round-trips', () {
    final province = _bangkok;
    final district = province.districts.first;
    final subdistrict = district.subdistricts.first;

    final full = ThaiAddressSelection(
      province: province,
      district: district,
      subdistrict: subdistrict,
    );
    expect(ThaiAddressSelection.fromJson(full.toJson()), equals(full));

    // Partial selection (province only).
    final partial = ThaiAddressSelection(province: province);
    final back = ThaiAddressSelection.fromJson(partial.toJson());
    expect(back, equals(partial));
    expect(back.district, isNull);
    expect(back.subdistrict, isNull);

    // Empty selection.
    expect(
      ThaiAddressSelection.fromJson(ThaiAddressSelection.empty.toJson()),
      equals(ThaiAddressSelection.empty),
    );
  });
}
