import 'package:thai_provinces/thai_provinces.dart';

/// Which language the [ThaiAddressPicker] dropdown labels are drawn in.
///
/// This only affects the human-readable text shown in the dropdowns; the
/// selected values ([Province]/[District]/[Subdistrict]) and the resulting
/// [ThaiAddressSelection] are language-independent.
enum ThaiAddressLanguage {
  /// Use the Thai names (`nameTh`).
  thai,

  /// Use the romanized English names (`nameEn`).
  english,

  /// Show both, as `"<Thai> (<English>)"` — e.g. `"กรุงเทพมหานคร (Bangkok)"`.
  /// Handled by [ThaiAddressLanguageLabels] (implemented by the language dev).
  bilingual,
}

/// Label helpers used by the picker to render names per [ThaiAddressLanguage].
extension ThaiAddressLanguageLabels on ThaiAddressLanguage {
  /// The display label for a [Province] in this language.
  String labelOf(Province p) => _label(p.nameTh, p.nameEn);

  /// The display label for a [District] in this language.
  String labelOfDistrict(District d) => _label(d.nameTh, d.nameEn);

  /// The display label for a [Subdistrict] in this language.
  String labelOfSubdistrict(Subdistrict s) => _label(s.nameTh, s.nameEn);

  /// Renders the label from the Thai and English names per this language.
  ///
  /// The exhaustive [switch] means adding a future [ThaiAddressLanguage] value
  /// will force a compile-time review of this method.
  String _label(String nameTh, String nameEn) {
    switch (this) {
      case ThaiAddressLanguage.thai:
        return nameTh;
      case ThaiAddressLanguage.english:
        return nameEn;
      case ThaiAddressLanguage.bilingual:
        return '$nameTh ($nameEn)';
    }
  }
}
