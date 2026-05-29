## 0.2.0

- Add `ThaiAddressAutocompleteField` — a single type-ahead field that resolves a
  free-text Thai/English name or a postal-code prefix to a full address and
  commits it to the shared `ThaiAddressController`. Built on Flutter's stock
  `Autocomplete`; no new dependencies, no code generation.
- Add `ThaiAddressSuggestion` and `thaiAddressSuggestions(query, {limit})` — the
  ranked, in-memory suggestion engine behind the field (subdistrict name prefix
  → contains → district/province expansion, plus 1–5 digit postcode-prefix
  matching), usable on its own. Each suggestion carries a `display(language)`
  breadcrumb (Thai uses แขวง/เขต for Bangkok, ตำบล/อำเภอ/จังหวัด elsewhere).

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
