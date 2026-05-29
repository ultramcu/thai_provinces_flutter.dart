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

## API

| Type | Kind | Purpose |
| --- | --- | --- |
| `ThaiAddressPicker` | Widget | Cascading province/district/subdistrict dropdowns + read-only postcode. |
| `ThaiAddressFormField` | `FormField` | `Form`-integrated picker with `validator` / `onSaved` / error text. |
| `ThaiAddressController` | `ValueNotifier` | Holds the selection; cascade-clearing, guarded setters (`setProvince` / `setDistrict` / `setSubdistrict` / `clear`). |
| `ThaiAddressSelection` | Value object | Immutable `{province, district, subdistrict}` snapshot; `postcode`, `isComplete`, `isEmpty`, `copyWith`, `toJson` / `fromJson`, value equality. |
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
