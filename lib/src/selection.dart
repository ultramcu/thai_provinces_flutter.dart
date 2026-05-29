import 'package:thai_provinces/thai_provinces.dart';

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
