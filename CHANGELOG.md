## 0.6.0

- Add `ThaiAddressSearchField` — a single-line address field that opens a
  full-screen, search-as-you-type picker on tap: type a Thai/English name or a
  postcode and pick a ranked breadcrumb result; the pick commits to the
  controller (cancel leaves it untouched). The "search your address" pattern,
  good for address books and dense forms.
- Add `showThaiAddressSearch(context, {language, searchHint})` — the imperative
  full-screen search behind the field (a `SearchDelegate` over the package's
  `thaiAddressSuggestions` engine), usable on its own; returns the chosen
  `ThaiAddressSelection` or `null` if dismissed. Built on stock `showSearch`; no
  new dependencies.

## 0.5.0

- Add `ThaiAddressSheetField` — a compact, single-line address field for dense
  forms (checkout etc.): it shows the current selection as one read-only summary
  line (via `ThaiAddressSelection.format`) and, when tapped, opens a modal
  bottom-sheet picker; confirming commits the new selection to the controller,
  cancelling leaves it untouched.
- Add `showThaiAddressSheet(context, {initial, language, title, confirmLabel})`
  — the imperative bottom-sheet picker behind the field, usable on its own;
  returns the chosen `ThaiAddressSelection` on confirm or `null` on cancel. It
  edits a private staging controller, so a cancelled edit never mutates the
  caller's state. Built on stock `showModalBottomSheet`; no new dependencies.

## 0.4.0

- Add `ThaiAddressPicker(fieldBuilder:)` — an escape hatch that lets you render a
  fully custom widget for any level (province / district / subdistrict) instead
  of the default dropdown, while the picker keeps owning the cascade, the
  clear-on-parent-change behaviour and the auto-filled postcode. The builder
  receives a `ThaiAddressFieldScope` (`level`, `options`, `selected`,
  `onSelected`, `enabled`, `label`); return `null` for a level to keep its
  default dropdown. New public types: `ThaiAddressLevel`, `ThaiAddressFieldScope`
  and the `ThaiAddressFieldBuilder` typedef.
- Add `ThaiAddressPicker(labelBuilder:)` — override the display label of any area
  option (`Province` / `District` / `Subdistrict`) without touching the
  selection. Falls back to the `language` default when `null`. New
  `ThaiAddressLabelBuilder` typedef.
- Add `ThaiAddressValidators` — ready-made `FormField` validators for a
  `ThaiAddressSelection`. `ThaiAddressValidators.required({language, message})`
  passes only for a complete selection and emits a default message localized to
  the chosen language (Thai / English / bilingual), or a custom `message`.
- Add `ThaiAddressLanguage.bilingual` — renders each label as `"<Thai> (<English>)"`
  (e.g. `"กรุงเทพมหานคร (Bangkok)"`) across the dropdowns, autocomplete, postcode
  chooser and the default validator message.
- Add **direct dropdown styling passthrough**. `ThaiAddressPicker` and
  `ThaiPostcodeField` now forward `style`, `dropdownColor`, `borderRadius`,
  `icon`, `iconEnabledColor` and `menuMaxHeight` straight to the underlying
  `DropdownButtonFormField`s; `ThaiAddressAutocompleteField` forwards `style` to
  its input field. Each is `null` by default and falls back to the ambient
  theme, so existing call sites are unaffected. This complements the two styling
  layers that already worked — the ambient `ThemeData` (`ColorScheme` /
  `InputDecorationTheme` / `dropdownMenuTheme`) and per-field
  `decoration: InputDecoration(...)` — see the README "Styling & theming"
  section.
- Accessibility coverage: tests assert the postcode field advertises
  `AutofillHints.postalCode` and that the dropdowns expose their labels to the
  semantics tree.
- Docs: new README sections for `fieldBuilder`, `labelBuilder`,
  `ThaiAddressValidators`, the bilingual language mode and a "Styling & theming"
  guide.

## 0.3.0

- Add `ThaiAddressSelection.format({language, includePostcode})` — a one-call
  printable postal-order address string. Thai uses the correct prefixes (แขวง +
  verbatim เขต…/กรุงเทพมหานคร for Bangkok; ตำบล/อำเภอ/จังหวัด elsewhere); English
  joins the romanized names with commas. Formats partial selections (only the
  set levels) and returns `''` for an empty selection.

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
