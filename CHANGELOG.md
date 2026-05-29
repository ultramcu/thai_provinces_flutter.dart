## 0.1.0

Initial release.

Cascading Thai address picker widgets (province → district → subdistrict +
postcode) for Flutter, with no state-management lock-in and no code generation.
Depends on exactly `flutter` and `thai_provinces`.

Public API:

- `ThaiAddressPicker` — a cascading widget of three `DropdownButtonFormField`s
  (province → district → subdistrict) plus an optional read-only postcode field.
  Supports an external or internally-owned controller, `onChanged`, Thai/English
  labels, per-field label overrides, custom `InputDecoration`, `enabled`,
  `showPostcode` and `spacing`.
- `ThaiAddressFormField` — a `FormField<ThaiAddressSelection>` wrapper that
  integrates with `Form`, `validator`, `onSaved`, `autovalidateMode` and inline
  error display.
- `ThaiAddressController` — a `ValueNotifier<ThaiAddressSelection>` with
  cascade-clearing, parent-guarded setters (`setProvince`, `setDistrict`,
  `setSubdistrict`) and `clear()`.
- `ThaiAddressSelection` — an immutable `{province, district, subdistrict}`
  snapshot with `postcode`, `isComplete`, `isEmpty`, `copyWith`, `toJson` /
  `fromJson` and value equality.
- `ThaiAddressLanguage` (`thai` / `english`) and the `ThaiAddressLanguageLabels`
  extension for rendering names.
- Re-exports `package:thai_provinces/thai_provinces.dart` (`Province`,
  `District`, `Subdistrict`, `provinces()`, `provinceByCode()`, …) so a single
  import is enough.
