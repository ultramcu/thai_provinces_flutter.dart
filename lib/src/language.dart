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
}

/// Label helpers used by the picker to render names per [ThaiAddressLanguage].
extension ThaiAddressLanguageLabels on ThaiAddressLanguage {
  /// The display label for a [Province] in this language.
  String labelOf(Province p) =>
      this == ThaiAddressLanguage.thai ? p.nameTh : p.nameEn;

  /// The display label for a [District] in this language.
  String labelOfDistrict(District d) =>
      this == ThaiAddressLanguage.thai ? d.nameTh : d.nameEn;

  /// The display label for a [Subdistrict] in this language.
  String labelOfSubdistrict(Subdistrict s) =>
      this == ThaiAddressLanguage.thai ? s.nameTh : s.nameEn;
}
