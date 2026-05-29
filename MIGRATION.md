# Migrating from `thai_address_picker`

This guide helps you move a Thai address form from
[`thai_address_picker`](https://pub.dev/packages/thai_address_picker) to
`thai_provinces_flutter`.

`thai_provinces_flutter` is a drop-in alternative whose distinguishing trait is
its dependency surface: it depends on exactly **`flutter`** and the
[`thai_provinces`](https://pub.dev/packages/thai_provinces) data core — **no
state-management library** (no riverpod / bloc / provider) and **no code
generation** (no `freezed` / `json_serializable` / `build_runner`). Selection
state lives in a plain `ValueNotifier` (`ThaiAddressController`), so it fits
whatever state approach your app already uses.

This document is a factual comparison to help you decide and migrate; it is not
a knock on `thai_address_picker`, which is a capable package.

## Dependency diff

Moving from `thai_address_picker` to `thai_provinces_flutter` lets you drop the
state-management and codegen toolchain that `thai_address_picker` requires.

| `pubspec.yaml` entry | `thai_address_picker` | `thai_provinces_flutter` |
| --- | --- | --- |
| `flutter` | required | required |
| `flutter_riverpod` | required (`^2.6.1`) | **not needed** |
| `freezed_annotation` | required (`^3.1.0`) | **not needed** |
| `json_annotation` | required (`^4.9.0`) | **not needed** |
| `build_runner` (dev) | required (codegen) | **not needed** |
| `freezed` (dev) | required (codegen) | **not needed** |
| `thai_provinces` | — | required (`^0.2.0`) |

Net effect: **remove** `flutter_riverpod`, `freezed_annotation`,
`json_annotation`, and the `build_runner` / `freezed` dev-dependencies; **add**
nothing beyond `thai_provinces` (a single dependency-free data package).

```sh
# Remove the old picker and its codegen toolchain
flutter pub remove thai_address_picker
flutter pub remove flutter_riverpod freezed_annotation json_annotation
dart pub remove build_runner freezed   # dev_dependencies

# Add the new picker (pulls in thai_provinces transitively)
flutter pub add thai_provinces_flutter
```

You no longer run `dart run build_runner build` (or `watch`) as part of your
build: this package is **zero-codegen**, so there are no generated `*.g.dart` /
`*.freezed.dart` files to maintain.

## Before / after

### Before — `thai_address_picker` (riverpod + freezed)

`thai_address_picker` builds on Riverpod, so a `ProviderScope` is needed at the
root when you use its built-in widgets:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thai_address_picker/thai_address_picker.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ThaiAddressForm(
          useThai: true,
          onChanged: (ThaiAddress address) {
            debugPrint('Province: ${address.provinceTh}');
            debugPrint('District: ${address.districtTh}');
            debugPrint('Sub-district: ${address.subDistrictTh}');
            debugPrint('Zip Code: ${address.zipCode}');
          },
        ),
      ),
    );
  }
}
```

### After — `thai_provinces_flutter` (no riverpod, no codegen)

No `ProviderScope`, no generated code. The picker is a plain widget; the
selection arrives through `onChanged` as a `ThaiAddressSelection`:

```dart
import 'package:flutter/material.dart';
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ThaiAddressPicker(
          onChanged: (ThaiAddressSelection sel) {
            debugPrint('Province: ${sel.province?.nameTh}');
            debugPrint('District: ${sel.district?.nameTh}');
            debugPrint('Sub-district: ${sel.subdistrict?.nameTh}');
            debugPrint('Zip Code: ${sel.postcode}');
          },
        ),
      ),
    );
  }
}
```

## Field mapping

`thai_address_picker` hands you a flat `ThaiAddress` value; this package hands
you a `ThaiAddressSelection` that exposes the strongly-typed core models
(`Province` / `District` / `Subdistrict`), each carrying its DOPA `code`.

| `ThaiAddress` (old) | `ThaiAddressSelection` (new) |
| --- | --- |
| `address.provinceTh` | `sel.province?.nameTh` |
| `address.provinceEn` | `sel.province?.nameEn` |
| `address.provinceId` | `sel.province?.code` |
| `address.districtTh` | `sel.district?.nameTh` |
| `address.districtEn` | `sel.district?.nameEn` |
| `address.districtId` | `sel.district?.code` |
| `address.subDistrictTh` | `sel.subdistrict?.nameTh` |
| `address.subDistrictEn` | `sel.subdistrict?.nameEn` |
| `address.subDistrictId` | `sel.subdistrict?.code` |
| `address.zipCode` | `sel.postcode` (an `int?`) |
| `address.lat` / `address.long` | *no equivalent* (this package carries no coordinates) |

Notes:

- The new fields are nullable because a selection can be partial mid-cascade.
  `sel.isComplete` tells you when all three levels are set; `sel.postcode` is
  non-null once a subdistrict is chosen.
- `thai_address_picker`'s `ThaiAddress` includes `lat` / `long`. This package
  does not carry latitude/longitude; if you need coordinates, keep sourcing
  them separately.
- The DOPA `code` integers (province 2-digit, district 4-digit, subdistrict
  6-digit) are the canonical identifiers and round-trip cleanly — see
  `fromCodes` / `toCodes` below.

## Feature parity

| Capability | `thai_address_picker` | `thai_provinces_flutter` |
| --- | --- | --- |
| Cascading province → district → subdistrict | yes | yes (`ThaiAddressPicker`) |
| Postcode reverse-lookup (zip → fill levels) | yes | yes (`ThaiPostcodeField`, `controller.setPostcode`) |
| Type-ahead / autocomplete | yes | yes (`ThaiAddressAutocompleteField`) |
| Thai / English labels | yes (`useThai`) | yes (`language:`) |
| `Form` validation integration | — | yes (`ThaiAddressFormField`) |
| State-management dependency | riverpod | **none** |
| Code generation | build_runner + freezed | **none** |
| Lat / long coordinates | yes | no |

Both packages cover cascading selection, reverse postcode lookup, and
autocomplete. The trade-off is dependency footprint and coordinates: this
package drops the riverpod + codegen toolchain (and ships no lat/long), while
`thai_address_picker` keeps them.

## Reusing stored codes

If your old data persisted province/district/subdistrict IDs (the
`provinceId` / `districtId` / `subDistrictId` values), they are DOPA geocodes
and map directly onto this package. Seed a picker straight from them — no
network, no lookup tables of your own:

```dart
import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';

// Rebuild a selection from a stored subdistrict code; the parent
// district and province are derived automatically.
final selection = ThaiAddressSelection.fromCodes(subdistrictCode: 500108);
// selection.province?.code == 50, selection.district?.code == 5001

// Or seed the picker directly:
const picker = ThaiAddressPicker(
  initialCodes: (50, 5001, 500108),
);
```

See the README's "Reverse lookup & codes" section for the full `fromCodes` /
`toCodes` round-trip and the postcode field.

## Checklist

1. `flutter pub remove thai_address_picker flutter_riverpod freezed_annotation json_annotation`
2. `dart pub remove build_runner freezed` (dev-dependencies)
3. `flutter pub add thai_provinces_flutter`
4. Delete the now-unused `ProviderScope` wrapper if it was only there for the picker.
5. Replace `ThaiAddressForm(...)` with `ThaiAddressPicker(...)` (or
   `ThaiAddressFormField` inside a `Form`).
6. Update `onChanged` to read `ThaiAddressSelection` fields per the mapping
   table above.
7. Re-point any persisted IDs through `ThaiAddressSelection.fromCodes(...)` /
   `ThaiAddressPicker(initialCodes: ...)`.
8. Drop `dart run build_runner ...` from your build scripts — there is nothing
   to generate.

That's it: no generated files, no provider scope, two dependencies total.
