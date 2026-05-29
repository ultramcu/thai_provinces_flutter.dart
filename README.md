# thai_provinces_flutter

Cascading Thai address picker widgets — จังหวัด → อำเภอ/เขต → ตำบล/แขวง + รหัสไปรษณีย์ — for Flutter, with **no state-management lock-in** and **no code generation**.

[![pub version](https://img.shields.io/pub/v/thai_provinces_flutter.svg)](https://pub.dev/packages/thai_provinces_flutter)
[![pub points](https://img.shields.io/pub/points/thai_provinces_flutter.svg)](https://pub.dev/packages/thai_provinces_flutter/score)
[![pub likes](https://img.shields.io/pub/likes/thai_provinces_flutter.svg)](https://pub.dev/packages/thai_provinces_flutter/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A drop-in province → district → subdistrict picker that auto-fills the postcode, speaks Thai or English, and plugs straight into a Flutter `Form`.

## Install

```sh
flutter pub add thai_provinces_flutter
```

This pulls in exactly two things: `flutter` and the [`thai_provinces`](https://pub.dev/packages/thai_provinces) data core. Nothing else.

## Why this package

Most Thai address pickers drag in a state-management framework or a code generator. This one does **neither**:

- **No state-management lock-in** — no provider / riverpod / bloc. Selection state lives in a plain `ValueNotifier` (`ThaiAddressController`). Use it with whatever you already use.
- **No code generation** — no freezed / json_serializable / build_runner. Just import and run.
- **Built on a verified data core** — all 77 provinces, 928 districts and 7,452 subdistricts come from [`thai_provinces`](https://pub.dev/packages/thai_provinces) (160/160 pub points), DOPA-validated.
- **Form-native** — `ThaiAddressFormField` integrates with `Form`, `validator`, `onSaved` and error display out of the box.

The core models (`Province`, `District`, `Subdistrict`) and lookup helpers (`provinces()`, `provinceByCode()`, …) are **re-exported**, so a single import gives you everything.

### Comparison

How it compares to [`thai_address_picker`](https://pub.dev/packages/thai_address_picker), the other Flutter Thai-address widget:

| | `thai_provinces_flutter` | `thai_address_picker` |
| --- | --- | --- |
| Runtime dependencies | `flutter` + `thai_provinces` only | `flutter` + `flutter_riverpod` + `freezed_annotation` + `json_annotation` |
| Code generation | none | `build_runner` + `freezed` |
| State-management lock-in | none (plain `ValueNotifier`) | riverpod (`ProviderScope`) |
| Cascading picker | yes | yes |
| Autocomplete / type-ahead | yes | yes |
| Postcode reverse-lookup | yes | yes |
| `Form` validation field | yes (`ThaiAddressFormField`) | — |
| Lat / long coordinates | no | yes |
| pub points | 160 / 160 *(core data package; this widget package's score builds on it)* | 150 |

Both packages do cascading selection, autocomplete and reverse postcode lookup. The difference is footprint: this package adds **no** state-management framework and **no** codegen step (but carries no lat/long). Migrating? See [MIGRATION.md](MIGRATION.md).

## Minimal example

A picker inside a `Form`, reporting changes through `onChanged`:

```dart
import 'package:flutter/material.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

class AddressForm extends StatelessWidget {
  const AddressForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Form(
      child: ThaiAddressPicker(
        onChanged: (sel) {
          debugPrint('province=${sel.province?.nameTh} postcode=${sel.postcode}');
        },
      ),
    );
  }
}
```

## Controller-driven example

Own a `ThaiAddressController` to read, drive, or clear the selection. `onChanged`
fires for **both** dropdown taps and programmatic `controller.setX()` calls — it is
the single source of truth.

```dart
final controller = ThaiAddressController();

ThaiAddressPicker(
  controller: controller,
  onChanged: (sel) => print(sel.toJson()),
);

// Drive it programmatically (cascade-clears the levels below):
controller.setProvince(provinceByCode(10)); // Bangkok
controller.clear();

// Read the current values:
final code = controller.subdistrict?.postcode;
```

## Form field + validator example

Require a complete address before the form will submit:

```dart
final formKey = GlobalKey<FormState>();

Form(
  key: formKey,
  child: Column(
    children: [
      ThaiAddressFormField(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (sel) =>
            (sel == null || !sel.isComplete) ? 'Please choose a full address' : null,
        onSaved: (sel) => submit(sel!),
      ),
      ElevatedButton(
        onPressed: () {
          if (formKey.currentState!.validate()) {
            formKey.currentState!.save();
          }
        },
        child: const Text('Submit'),
      ),
    ],
  ),
);
```

## Autocomplete (type-ahead)

`ThaiAddressAutocompleteField` resolves a free-text query — a Thai or English
subdistrict / district / province name, or a postcode prefix — to a full
selection in a single field. Picking a suggestion cascades into the controller,
so `onChanged` reports the same `ThaiAddressSelection` as the picker does.

```dart
import 'package:flutter/material.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

class AddressSearch extends StatelessWidget {
  const AddressSearch({super.key});

  @override
  Widget build(BuildContext context) {
    return ThaiAddressAutocompleteField(
      decoration: const InputDecoration(labelText: 'ค้นหาที่อยู่'),
      maxOptions: 10,
      onChanged: (sel) =>
          debugPrint('${sel.subdistrict?.nameTh} ${sel.postcode}'),
    );
  }
}
```

## Postcode field (reverse lookup)

`ThaiPostcodeField` is postcode-first: the user types a 5-digit code and the
address auto-fills as far as the postcode is unambiguous — the province and
district are set only when *every* matching subdistrict shares them (most
postcodes do, but ~18% span several districts and a few span several provinces),
and the subdistrict is filled when the postcode is 1:1. When several
subdistricts share the code, the field shows an inline chooser so the user picks
one (resolving the whole address). The same logic is available programmatically
via `controller.setPostcode(int)`.

```dart
import 'package:flutter/material.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

class PostcodeEntry extends StatelessWidget {
  const PostcodeEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return ThaiPostcodeField(
      decoration: const InputDecoration(labelText: 'รหัสไปรษณีย์'),
      onChanged: (sel) => debugPrint(
        '${sel.province?.nameTh} / ${sel.district?.nameTh} / '
        '${sel.subdistrict?.nameTh}',
      ),
    );
  }
}

// Or drive a controller directly:
final controller = ThaiAddressController();
controller.setPostcode(10800); // 1:1 → fills แขวงบางซื่อ, เขตบางซื่อ, กรุงเทพฯ
controller.setPostcode(50200); // 1 district, 3 subdistricts → province+district
controller.setPostcode(13240); // spans 2 provinces → nothing pinned; use chooser
```

## Codes (DOPA geocodes)

Every level carries its official DOPA `code` (province 2-digit, district
4-digit, subdistrict 6-digit). Store a single integer per level and rebuild the
selection later with `ThaiAddressSelection.fromCodes` — missing parents are
derived from the deepest code given. `toCodes()` is the inverse and round-trips.

```dart
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

// Rebuild from a stored subdistrict code; district + province are derived.
final sel = ThaiAddressSelection.fromCodes(subdistrictCode: 500108);
// sel.province?.code == 50, sel.district?.code == 5001, sel.postcode == 50200

// Inverse: read the codes back out.
final (p, d, s) = sel.toCodes(); // (50, 5001, 500108)
final same = ThaiAddressSelection.fromCodes(
  provinceCode: p,
  districtCode: d,
  subdistrictCode: s,
);
assert(same == sel); // round-trips

// On a live controller:
final controller = ThaiAddressController();
controller.setFromCodes(subdistrictCode: 500108);
```

### Seeding a picker with `initialCodes`

Pass stored codes straight to the picker to pre-select an address on first
build. `initialCodes` is applied once; it never clobbers a supplied controller
that already holds a non-empty selection.

```dart
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

// (provinceCode, districtCode, subdistrictCode)
const picker = ThaiAddressPicker(initialCodes: (50, 5001, 500108));

// A deeper-only code works too — parents are derived:
const fromSub = ThaiAddressPicker(initialCodes: (null, null, 500108));
```

## API

| Type | Kind | Purpose |
| --- | --- | --- |
| `ThaiAddressPicker` | Widget | Cascading province/district/subdistrict dropdowns + read-only postcode. Optional `initialCodes` seed. |
| `ThaiAddressAutocompleteField` | Widget | Single type-ahead field resolving a free-text name / postcode-prefix query to a full selection. |
| `ThaiPostcodeField` | Widget | Postcode-first field: 5-digit entry fills the levels the code shares unambiguously, plus an inline subdistrict chooser when several subdistricts match. |
| `ThaiAddressFormField` | `FormField` | `Form`-integrated picker with `validator` / `onSaved` / error text. |
| `ThaiAddressController` | `ValueNotifier` | Holds the selection; cascade-clearing, guarded setters (`setProvince` / `setDistrict` / `setSubdistrict` / `setPostcode` / `setFromCodes` / `clear`). |
| `ThaiAddressSelection` | Value object | Immutable `{province, district, subdistrict}` snapshot; `postcode`, `isComplete`, `isEmpty`, `copyWith`, `fromCodes` / `toCodes`, `toJson` / `fromJson`, value equality. |
| `ThaiAddressLanguage` | Enum | `thai` or `english` — picks which label names render. |
| `ThaiAddressLanguageLabels` | Extension | `labelOf` / `labelOfDistrict` / `labelOfSubdistrict` helpers. |
| `Province`, `District`, `Subdistrict` | Re-exported models | From `thai_provinces`. |
| `provinces()`, `provinceByCode()`, … | Re-exported helpers | From `thai_provinces`. |

### Notes

- `ThaiAddressSelection.postcode` is an `int?` (it comes from the core `Subdistrict.postcode`, an `int`); the read-only postcode field stringifies it.
- The controller's setters are **guarded**: passing a district/subdistrict that does not belong to the current parent is a no-op in release builds and trips an `assert` in debug builds, so the held selection is never left inconsistent.
- An external controller you pass in is **never disposed** by the widgets; an internally created one is.

## Language (TH / EN)

Set `language: ThaiAddressLanguage.thai` (default) or `ThaiAddressLanguage.english`
to switch the dropdown option text and the default field labels
(จังหวัด/อำเภอ-เขต/ตำบล-แขวง/รหัสไปรษณีย์ vs Province/District/Subdistrict/Postcode).
The *selected values* are language-independent — only the displayed text changes.
A caller-set `decoration.labelText`, or the per-field `provinceLabel` /
`districtLabel` / `subdistrictLabel` / `postcodeLabel` arguments, override the
defaults.

## Screenshots

> _Screenshots coming soon._ Run the [`example/`](example/) app to see the picker live:
>
> ```sh
> cd example && flutter run
> ```

## Credits & license

- Data and core models: [`thai_provinces`](https://pub.dev/packages/thai_provinces) — Thai province/district/subdistrict + postal data, DOPA-validated.
- Released under the [MIT License](LICENSE).
