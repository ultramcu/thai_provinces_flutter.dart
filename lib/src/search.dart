import 'package:flutter/material.dart';

import 'language.dart';
import 'selection.dart';
import 'suggestions.dart';

/// Opens a full-screen search (via Flutter's [showSearch]) where the user types
/// a Thai/English subdistrict/district/province name or a postcode prefix and
/// picks a ranked address suggestion. Resolves to the chosen
/// [ThaiAddressSelection], or `null` if the search is dismissed without a pick.
///
/// [language] drives the suggestion breadcrumb labels; [searchHint] overrides
/// the search field's placeholder (falls back to a localized default). Backed
/// by the package's own suggestion engine ([thaiAddressSuggestions]); no extra
/// dependencies.
Future<ThaiAddressSelection?> showThaiAddressSearch(
  BuildContext context, {
  ThaiAddressLanguage language = ThaiAddressLanguage.thai,
  String? searchHint,
}) {
  return showSearch<ThaiAddressSelection?>(
    context: context,
    delegate: _ThaiAddressSearchDelegate(
      language: language,
      searchHint: searchHint,
    ),
  );
}

bool _isThai(ThaiAddressLanguage l) => l == ThaiAddressLanguage.thai;

/// Full-screen search over [thaiAddressSuggestions], rendering each match as a
/// breadcrumb tile; tapping a tile closes the search with that selection.
class _ThaiAddressSearchDelegate extends SearchDelegate<ThaiAddressSelection?> {
  _ThaiAddressSearchDelegate({required this.language, String? searchHint})
    : super(
        searchFieldLabel:
            searchHint ??
            (_isThai(language) ? 'ค้นหาที่อยู่' : 'Search address'),
      );

  final ThaiAddressLanguage language;

  /// Maximum number of suggestions shown at once.
  static const int _limit = 30;

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        icon: const Icon(Icons.clear),
        tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) =>
      BackButton(onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _isThai(language)
                ? 'พิมพ์ชื่อตำบล/อำเภอ/จังหวัด หรือรหัสไปรษณีย์'
                : 'Type a subdistrict, district, province or postcode',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final results = thaiAddressSuggestions(q, limit: _limit);
    if (results.isEmpty) {
      return Center(
        child: Text(_isThai(language) ? 'ไม่พบที่อยู่' : 'No matches'),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final s = results[i];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(s.display(language)),
          onTap: () => close(context, s.selection),
        );
      },
    );
  }
}
