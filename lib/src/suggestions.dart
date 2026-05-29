import 'package:thai_provinces/thai_provinces.dart';

import 'language.dart';
import 'selection.dart';

/// A fully-resolved address suggestion produced from a free-text query by
/// [thaiAddressSuggestions]: a concrete [subdistrict] together with its owning
/// [district] and [province], ready to drop into a `ThaiAddressController`.
class ThaiAddressSuggestion {
  /// Creates a suggestion from a resolved province/district/subdistrict triple.
  const ThaiAddressSuggestion({
    required this.province,
    required this.district,
    required this.subdistrict,
  });

  /// The owning province.
  final Province province;

  /// The owning district.
  final District district;

  /// The matched subdistrict.
  final Subdistrict subdistrict;

  /// The 5-digit postal code of the [subdistrict].
  int get postcode => subdistrict.postcode;

  /// The selection this suggestion commits to when picked.
  ThaiAddressSelection get selection => ThaiAddressSelection(
    province: province,
    district: district,
    subdistrict: subdistrict,
  );

  /// A human-readable one-line breadcrumb for this suggestion in [language].
  ///
  /// Used as the autocomplete option label and as the field text after a pick.
  ///
  /// In Thai the breadcrumb reads
  /// `"ตำบล<sub> อำเภอ<dist> จังหวัด<prov> <postcode>"`, e.g.
  /// `"ตำบลสุเทพ อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่ 50200"`.
  ///
  /// ## Bangkok wording
  /// Bangkok (province code `10`) uses the special administrative vocabulary:
  /// its subdistricts are *แขวง* and its districts are *เขต* (not *ตำบล* /
  /// *อำเภอ*), and the province itself is *กรุงเทพมหานคร* — which already names
  /// the city, so the redundant *จังหวัด* prefix is dropped.
  ///
  /// Note the underlying dataset already bakes the *เขต* / *Khet* prefix into
  /// the district *name* for Bangkok (e.g. `nameTh == "เขตพระนคร"`,
  /// `nameEn == "Khet Phra Nakhon"`), while non-Bangkok districts store the
  /// bare name (e.g. `"เมืองเชียงใหม่"`). So this method prepends the
  /// administrative word to the *district* only outside Bangkok, and inside
  /// Bangkok uses the district name verbatim. A Bangkok breadcrumb reads
  /// `"แขวง<sub> <dist> กรุงเทพมหานคร <postcode>"`, e.g.
  /// `"แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร 10200"`.
  ///
  /// In English the breadcrumb is `"<subEn>, <distEn>, <provEn> <postcode>"`
  /// for every province (Bangkok included), e.g.
  /// `"Suthep, Mueang Chiang Mai, Chiang Mai 50200"` and
  /// `"Phra Borom Maha Ratchawang, Khet Phra Nakhon, Bangkok 10200"`. The
  /// dataset's English names already encode any Bangkok-specific romanization,
  /// so no special casing is needed there.
  String display(ThaiAddressLanguage language) {
    if (language == ThaiAddressLanguage.english) {
      return '${subdistrict.nameEn}, ${district.nameEn}, '
          '${province.nameEn} $postcode';
    }
    // Thai.
    if (province.code == _bangkokCode) {
      // District name already carries its "เขต" prefix in the dataset.
      return 'แขวง${subdistrict.nameTh} ${district.nameTh} '
          '${province.nameTh} $postcode';
    }
    return 'ตำบล${subdistrict.nameTh} อำเภอ${district.nameTh} '
        'จังหวัด${province.nameTh} $postcode';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThaiAddressSuggestion &&
          other.province == province &&
          other.district == district &&
          other.subdistrict == subdistrict;

  @override
  int get hashCode => Object.hash(province, district, subdistrict);

  @override
  String toString() =>
      'ThaiAddressSuggestion(${subdistrict.nameEn}, ${district.nameEn}, '
      '${province.nameEn}, $postcode)';
}

/// Province code of Bangkok (กรุงเทพมหานคร), which uses แขวง/เขต wording.
const int _bangkokCode = 10;

/// Returns up to [limit] ranked [ThaiAddressSuggestion]s for a free-text
/// [query].
///
/// Backs an autocomplete field. The query is interpreted as one of two kinds:
///
///  * **Postal code** — when the trimmed query is all ASCII digits. A full
///    5-digit code uses [byPostcode]; a 1–4 digit prefix keeps every
///    subdistrict whose 5-digit postcode *starts with* those digits. Results
///    are ordered by ascending postcode, then subdistrict code.
///  * **Name** — otherwise. Subdistricts are ranked, best first:
///      1. subdistrict Thai/English **prefix** matches ([searchSubdistricts]);
///      2. subdistrict Thai/English **contains** matches not already included;
///      3. subdistricts of any **district** whose name prefix-matches the
///         query (lower priority);
///      4. subdistricts of any **province** whose name prefix-matches the
///         query (lowest priority).
///    Tiers 3–4 only contribute while there is still room under [limit], so a
///    specific subdistrict query is never crowded out by a broad
///    province/district expansion. Matching uses [normalizeName] (case- and
///    admin-prefix-insensitive).
///
/// Every kept subdistrict is expanded to its owning district and province;
/// a subdistrict whose hierarchy cannot be resolved is skipped. Results are
/// de-duplicated by subdistrict code, preserve a stable rank-then-code order,
/// and are capped at [limit]. An empty/whitespace query returns `const []`.
///
/// The lookup is synchronous and operates entirely on the in-memory dataset.
List<ThaiAddressSuggestion> thaiAddressSuggestions(
  String query, {
  int limit = 20,
}) {
  final trimmed = query.trim();
  if (trimmed.isEmpty || limit <= 0) return const [];

  if (_isAsciiDigits(trimmed)) {
    return _byPostcodePrefix(trimmed, limit);
  }
  return _byName(trimmed, limit);
}

/// Whether [s] is non-empty and consists solely of ASCII digits `0`–`9`.
bool _isAsciiDigits(String s) {
  if (s.isEmpty) return false;
  for (final unit in s.codeUnits) {
    if (unit < 0x30 || unit > 0x39) return false;
  }
  return true;
}

/// Builds suggestions for an all-digit [digits] query (postal code / prefix).
List<ThaiAddressSuggestion> _byPostcodePrefix(String digits, int limit) {
  final accumulator = _SuggestionAccumulator(limit);

  if (digits.length == 5) {
    final code = int.tryParse(digits);
    if (code != null) {
      for (final s in byPostcode(code)) {
        accumulator.add(s);
        if (accumulator.isFull) break;
      }
    }
    return accumulator.toList();
  }

  // 1–4 digit prefix (a 6+ digit string cannot be a Thai postcode prefix).
  if (digits.length > 5) return const [];

  // Scan subdistricts in code order; keep those whose 5-digit postcode string
  // starts with the typed digits. Collect then sort by postcode for a tidy,
  // ascending list (subdistricts() is already subdistrict-code ordered, which
  // breaks ties stably).
  final matches = <Subdistrict>[];
  for (final s in subdistricts()) {
    final code = s.postcode;
    if (code < 10000 || code > 99999) continue; // guard non-5-digit data
    if (code.toString().startsWith(digits)) matches.add(s);
  }
  matches.sort((a, b) {
    final byCode = a.postcode.compareTo(b.postcode);
    if (byCode != 0) return byCode;
    return a.code.compareTo(b.code);
  });
  for (final s in matches) {
    accumulator.add(s);
    if (accumulator.isFull) break;
  }
  return accumulator.toList();
}

/// Builds suggestions for a non-digit name [query].
List<ThaiAddressSuggestion> _byName(String query, int limit) {
  final accumulator = _SuggestionAccumulator(limit);
  final q = normalizeName(query);
  if (q.isEmpty) return const [];

  // Tier 1: subdistrict name prefix matches.
  for (final s in searchSubdistricts(query)) {
    accumulator.add(s);
    if (accumulator.isFull) return accumulator.toList();
  }

  // Tier 2: subdistrict name contains matches (not already added).
  for (final s in subdistricts()) {
    final th = normalizeName(s.nameTh);
    final en = normalizeName(s.nameEn);
    if (th.contains(q) || en.contains(q)) {
      accumulator.add(s);
      if (accumulator.isFull) return accumulator.toList();
    }
  }

  // Tier 3: subdistricts of districts whose name prefix-matches (lower
  // priority). Only expand while there is still room.
  for (final d in searchDistricts(query)) {
    for (final s in d.subdistricts) {
      accumulator.add(s);
      if (accumulator.isFull) return accumulator.toList();
    }
  }

  // Tier 4: subdistricts of provinces whose name prefix-matches (lowest
  // priority).
  for (final p in searchProvinces(query)) {
    for (final d in p.districts) {
      for (final s in d.subdistricts) {
        accumulator.add(s);
        if (accumulator.isFull) return accumulator.toList();
      }
    }
  }

  return accumulator.toList();
}

/// Collects [Subdistrict]s into resolved [ThaiAddressSuggestion]s, dropping
/// duplicates (by subdistrict code) and anything whose district/province
/// cannot be resolved, while preserving insertion order and honoring a [limit].
class _SuggestionAccumulator {
  _SuggestionAccumulator(this.limit);

  /// Maximum number of suggestions to keep.
  final int limit;

  final _seen = <int>{};
  final _out = <ThaiAddressSuggestion>[];

  /// Whether the accumulator has reached its [limit].
  bool get isFull => _out.length >= limit;

  /// Resolves and appends [s] unless it is a duplicate, unresolvable, or the
  /// accumulator is already full.
  void add(Subdistrict s) {
    if (isFull || !_seen.add(s.code)) return;
    final d = s.district;
    final p = s.province;
    if (d == null || p == null) return;
    _out.add(ThaiAddressSuggestion(province: p, district: d, subdistrict: s));
  }

  /// The accumulated suggestions in stable order.
  List<ThaiAddressSuggestion> toList() => List.unmodifiable(_out);
}
