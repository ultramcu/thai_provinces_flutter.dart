import 'package:flutter/foundation.dart';
import 'package:thai_provinces/thai_provinces.dart';

import 'selection.dart';

/// A [ValueNotifier] holding a [ThaiAddressSelection], with cascade-clearing
/// setters for each level.
///
/// Setting a higher level clears the levels below it:
///  * [setProvince] clears the district and subdistrict.
///  * [setDistrict] clears the subdistrict.
///  * [setSubdistrict] sets only the subdistrict.
///
/// ## Consistency guards
/// The setters validate that the value belongs to the current parent:
///  * [setDistrict] is ignored (a no-op) if the district's `provinceCode`
///    does not match the currently selected province, or if no province is
///    selected. In debug builds this also trips an `assert`.
///  * [setSubdistrict] is ignored (a no-op) if the subdistrict's
///    `districtCode` does not match the currently selected district, or if no
///    district is selected. In debug builds this also trips an `assert`.
///
/// This keeps the held [ThaiAddressSelection] internally consistent at all
/// times, so widgets can trust it.
class ThaiAddressController extends ValueNotifier<ThaiAddressSelection> {
  /// Creates a controller, optionally seeded with [initial] (defaults to an
  /// empty selection).
  ThaiAddressController({ThaiAddressSelection? initial})
    : super(initial ?? ThaiAddressSelection.empty);

  /// The currently selected province, or `null`.
  Province? get province => value.province;

  /// The currently selected district, or `null`.
  District? get district => value.district;

  /// The currently selected subdistrict, or `null`.
  Subdistrict? get subdistrict => value.subdistrict;

  /// Sets (or clears) the province, cascade-clearing district and subdistrict.
  ///
  /// Passing the already-selected province is a no-op (no notification).
  void setProvince(Province? province) {
    if (province == value.province &&
        value.district == null &&
        value.subdistrict == null) {
      return;
    }
    value = ThaiAddressSelection(province: province);
  }

  /// Sets (or clears) the district, cascade-clearing the subdistrict.
  ///
  /// Ignored (no-op) when [district] is non-null but does not belong to the
  /// currently selected province (asserts in debug builds). Passing `null`
  /// clears the district and subdistrict.
  void setDistrict(District? district) {
    if (district != null) {
      final province = value.province;
      assert(
        province != null && district.provinceCode == province.code,
        'setDistrict($district) does not belong to the selected province '
        '${value.province}',
      );
      if (province == null || district.provinceCode != province.code) {
        return;
      }
    }
    if (district == value.district && value.subdistrict == null) {
      return;
    }
    value = ThaiAddressSelection(province: value.province, district: district);
  }

  /// Sets (or clears) the subdistrict.
  ///
  /// Ignored (no-op) when [subdistrict] is non-null but does not belong to the
  /// currently selected district (asserts in debug builds). Passing `null`
  /// clears the subdistrict.
  void setSubdistrict(Subdistrict? subdistrict) {
    if (subdistrict != null) {
      final district = value.district;
      assert(
        district != null && subdistrict.districtCode == district.code,
        'setSubdistrict($subdistrict) does not belong to the selected '
        'district ${value.district}',
      );
      if (district == null || subdistrict.districtCode != district.code) {
        return;
      }
    }
    if (subdistrict == value.subdistrict) {
      return;
    }
    value = ThaiAddressSelection(
      province: value.province,
      district: value.district,
      subdistrict: subdistrict,
    );
  }

  /// Sets the selection from a 5-digit postal [postcode].
  ///
  /// Resolves via `byPostcode` and pins only the levels the matches AGREE on:
  /// the province (and district) are set only when every matching subdistrict
  /// shares it, and the subdistrict is set only when exactly one matches. A
  /// postcode is not 1:1 with a district — about 18% of Thai postcodes span
  /// several districts, and a few span several provinces — so an ambiguous
  /// postcode leaves the unshared levels null for the UI to disambiguate over
  /// the full candidate set. An unknown postcode clears the selection.
  void setPostcode(int postcode) {
    final subs = byPostcode(postcode);
    if (subs.isEmpty) {
      clear();
      return;
    }
    final first = subs.first;
    // Pin a level only when ALL matches agree on it (compare by code).
    final sharedProvince = subs.every(
      (s) => s.districtCode ~/ 100 == first.districtCode ~/ 100,
    );
    final sharedDistrict = subs.every(
      (s) => s.districtCode == first.districtCode,
    );
    value = ThaiAddressSelection(
      province: sharedProvince ? first.province : null,
      district: sharedDistrict ? first.district : null,
      // Auto-fill the subdistrict only when the postcode is unambiguous.
      subdistrict: subs.length == 1 ? first : null,
    );
  }

  /// Sets the selection from official DOPA codes (see
  /// [ThaiAddressSelection.fromCodes]). Implemented by the codes dev.
  void setFromCodes({
    int? provinceCode,
    int? districtCode,
    int? subdistrictCode,
  }) {
    value = ThaiAddressSelection.fromCodes(
      provinceCode: provinceCode,
      districtCode: districtCode,
      subdistrictCode: subdistrictCode,
    );
  }

  /// Clears the entire selection.
  void clear() {
    if (value.isEmpty) return;
    value = ThaiAddressSelection.empty;
  }
}
