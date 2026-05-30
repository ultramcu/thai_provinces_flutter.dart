## 0.2.2

- Add an example **gallery** app (every form-factor on one shared controller
  with a live selection readout) and a **live web demo** deployed to GitHub
  Pages: https://ultramcu.github.io/thai_provinces_flutter.dart/
- Add `screenshots:` to the package (shown on pub.dev) and a screenshot + demo
  link in the README. No library code changes.

## 0.2.1

- Docs only: the README now presents this package's own capabilities (the
  "At a glance" table lists only this package; the third-party comparison and
  migration guide were removed). No code changes.

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
- Add `ThaiPostcodeField` — a postcode-first field. `controller.setPostcode(int)`
  fills the levels every matching subdistrict shares (a postcode is not 1:1 with
  a district — ~18% span several districts and a few several provinces) and the
  subdistrict when 1:1; an inline chooser disambiguates the rest and resolves
  the full address even when no parent could be pinned.
- Add the DOPA-codes codec: `ThaiAddressSelection.fromCodes`/`toCodes` (derives
  missing parents from the deepest code; round-trips), `controller.setFromCodes`,
  and `ThaiAddressPicker(initialCodes:)` to prefill from stored codes without
  clobbering a non-empty supplied controller.
- Docs: README usage sections for the new APIs.

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
