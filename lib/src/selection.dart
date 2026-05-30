import 'package:thai_provinces/thai_provinces.dart';

import 'language.dart';

/// An immutable snapshot of a (possibly partial) Thai address selection:
/// a [province], its [district] and that district's [subdistrict].
///
/// All three fields are nullable so the value can represent any stage of a
/// cascading pick. The derived [postcode] comes from the chosen [subdistrict].
///
/// The class has value equality and is JSON round-trippable via [toJson] /
/// [ThaiAddressSelection.fromJson], delegating to the core models'
/// `toJson`/`fromJson`.
class ThaiAddressSelection {
  /// Creates an address selection. Any field may be `null` to represent a
  /// partial pick. No cross-field consistency is enforced here — that is the
  /// job of [ThaiAddressController].
  const ThaiAddressSelection({this.province, this.district, this.subdistrict});

  /// An empty selection (nothing chosen).
  static const ThaiAddressSelection empty = ThaiAddressSelection();

  /// The chosen province, or `null`.
  final Province? province;

  /// The chosen district, or `null`.
  final District? district;

  /// The chosen subdistrict, or `null`.
  final Subdistrict? subdistrict;

  /// The 5-digit postal code of the chosen [subdistrict], or `null` if no
  /// subdistrict is selected.
  int? get postcode => subdistrict?.postcode;

  /// Whether all three levels have been chosen.
  bool get isComplete =>
      province != null && district != null && subdistrict != null;

  /// Whether nothing has been chosen.
  bool get isEmpty =>
      province == null && district == null && subdistrict == null;

  /// Returns a copy with the given fields replaced.
  ///
  /// Because the fields are nullable, an explicit `null` is indistinguishable
  /// from "leave unchanged": this `copyWith` only replaces a field whose
  /// argument is non-null and never clears one. No clearing sentinel is
  /// provided — clearing is handled by `ThaiAddressController`, which
  /// constructs fresh [ThaiAddressSelection]s directly.
  ThaiAddressSelection copyWith({
    Province? province,
    District? district,
    Subdistrict? subdistrict,
  }) {
    return ThaiAddressSelection(
      province: province ?? this.province,
      district: district ?? this.district,
      subdistrict: subdistrict ?? this.subdistrict,
    );
  }

  /// A JSON map of this selection. Each present level is emitted as the core
  /// model's own `toJson()` map under `province`/`district`/`subdistrict`;
  /// absent levels are emitted as `null`. Round-trippable via [fromJson].
  Map<String, dynamic> toJson() => {
    'province': province?.toJson(),
    'district': district?.toJson(),
    'subdistrict': subdistrict?.toJson(),
  };

  /// Rebuilds a selection from a [toJson] map. Missing or `null` levels become
  /// `null`. Malformed level maps propagate the core models' [FormatException].
  factory ThaiAddressSelection.fromJson(Map<String, dynamic> json) {
    final p = json['province'];
    final d = json['district'];
    final s = json['subdistrict'];
    return ThaiAddressSelection(
      province: p == null
          ? null
          : Province.fromJson((p as Map).cast<String, dynamic>()),
      district: d == null
          ? null
          : District.fromJson((d as Map).cast<String, dynamic>()),
      subdistrict: s == null
          ? null
          : Subdistrict.fromJson((s as Map).cast<String, dynamic>()),
    );
  }

  /// Builds a selection from official DOPA codes by looking each present code
  /// up in the embedded dataset (`provinceByCode`/`districtByCode`/
  /// `subdistrictByCode`). When a parent code is omitted but a deeper code is
  /// given, the missing parents are derived from the deepest code, so
  /// `ThaiAddressSelection.fromCodes(subdistrictCode: 500108)` yields a full
  /// selection. An unknown code becomes `null` at that level. Implemented by
  /// the codes dev.
  factory ThaiAddressSelection.fromCodes({
    int? provinceCode,
    int? districtCode,
    int? subdistrictCode,
  }) {
    // Resolve the deepest level given, then derive any missing parents from it.
    // A missing parent is filled only from a *resolved* child (never fabricated
    // from a null lookup). An explicitly-given parent code, if present, still
    // governs its own level (so an unknown given code stays null even if a
    // child would have implied a value — the given code "wins" at its level).
    final subdistrict = subdistrictCode == null
        ? null
        : subdistrictByCode(subdistrictCode);

    // District: prefer the resolved subdistrict's district; otherwise resolve
    // the given district code (if any).
    District? district = subdistrict?.district;
    if (district == null && districtCode != null) {
      district = districtByCode(districtCode);
    }

    // Province: prefer the resolved subdistrict's/district's province; else the
    // given province code (if any).
    Province? province = subdistrict?.province ?? district?.province;
    if (province == null && provinceCode != null) {
      province = provinceByCode(provinceCode);
    }

    return ThaiAddressSelection(
      province: province,
      district: district,
      subdistrict: subdistrict,
    );
  }

  /// The `(provinceCode, districtCode, subdistrictCode)` of this selection;
  /// each element is `null` where that level is unset. Round-trips with
  /// [ThaiAddressSelection.fromCodes]. Implemented by the codes dev.
  (int? provinceCode, int? districtCode, int? subdistrictCode) toCodes() =>
      (province?.code, district?.code, subdistrict?.code);

  /// A printable postal-order address string for the levels that are set.
  ///
  /// Thai ([ThaiAddressLanguage.thai]) joins subdistrict → district → province
  /// with the correct prefixes: Bangkok (province code 10) uses แขวง for the
  /// subdistrict and the district/province names verbatim (they already read
  /// เขต…/กรุงเทพมหานคร), while elsewhere it is ตำบล…/อำเภอ…/จังหวัด…. English
  /// ([ThaiAddressLanguage.english]) joins the romanized names with commas. The
  /// 5-digit postcode is appended when [includePostcode] is true and a
  /// subdistrict is set. A partial selection formats only the set levels; an
  /// empty selection returns an empty string. Implemented by the dev.
  String format({
    ThaiAddressLanguage language = ThaiAddressLanguage.thai,
    bool includePostcode = true,
  }) {
    // Bangkok detection from the deepest available level's province code.
    final provinceCode =
        province?.code ??
        district?.provinceCode ??
        (subdistrict != null ? subdistrict!.districtCode ~/ 100 : null);
    final isBangkok = provinceCode == _bangkokCode;

    final parts = <String>[];
    if (language == ThaiAddressLanguage.english) {
      if (subdistrict != null) parts.add(subdistrict!.nameEn);
      if (district != null) parts.add(district!.nameEn);
      if (province != null) parts.add(province!.nameEn);
      var out = parts.join(', ');
      if (includePostcode && subdistrict != null) {
        out = out.isEmpty
            ? '${subdistrict!.postcode}'
            : '$out ${subdistrict!.postcode}';
      }
      return out;
    }

    // Thai.
    if (subdistrict != null) {
      parts.add('${isBangkok ? 'แขวง' : 'ตำบล'}${subdistrict!.nameTh}');
    }
    if (district != null) {
      // Bangkok district names already carry the "เขต" prefix in the dataset.
      parts.add(isBangkok ? district!.nameTh : 'อำเภอ${district!.nameTh}');
    }
    if (province != null) {
      // The Bangkok province name is "กรุงเทพมหานคร" and is used verbatim.
      parts.add(isBangkok ? province!.nameTh : 'จังหวัด${province!.nameTh}');
    }
    var out = parts.join(' ');
    if (includePostcode && subdistrict != null) {
      out = out.isEmpty
          ? '${subdistrict!.postcode}'
          : '$out ${subdistrict!.postcode}';
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThaiAddressSelection &&
          other.province == province &&
          other.district == district &&
          other.subdistrict == subdistrict;

  @override
  int get hashCode => Object.hash(province, district, subdistrict);

  @override
  String toString() =>
      'ThaiAddressSelection(province: $province, district: $district, '
      'subdistrict: $subdistrict)';
}

/// Province code of Bangkok (กรุงเทพมหานคร), which uses แขวง/เขต wording.
const int _bangkokCode = 10;
