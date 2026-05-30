import 'package:flutter/material.dart';

import 'controller.dart';
import 'language.dart';
import 'search.dart';
import 'selection.dart';

/// A single-line address field that opens a **full-screen search** when tapped:
/// it shows the current selection as a read-only summary line (via
/// [ThaiAddressSelection.format]) and, on tap, launches [showThaiAddressSearch];
/// picking a result commits the new selection to the (shared or internal)
/// controller.
///
/// This is the "search your address" pattern (good for address books and dense
/// forms where type-to-find beats cascading dropdowns). Built on stock Flutter
/// widgets; no extra dependencies. Driven by the controller, so it works inside
/// a `Form`.
class ThaiAddressSearchField extends StatefulWidget {
  /// Creates a search-style Thai address field.
  const ThaiAddressSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.language = ThaiAddressLanguage.thai,
    this.decoration = const InputDecoration(),
    this.enabled = true,
    this.hint,
    this.searchHint,
  });

  /// The controller holding the current selection. If `null`, the field creates
  /// and owns an internal controller and disposes it automatically.
  final ThaiAddressController? controller;

  /// Called whenever the selection changes (after a picked search result or a
  /// programmatic controller change).
  final ValueChanged<ThaiAddressSelection>? onChanged;

  /// Language for the summary line and the search suggestions.
  final ThaiAddressLanguage language;

  /// Decoration for the collapsed summary field (label, border, icon, …).
  final InputDecoration decoration;

  /// Whether the field is interactive (tappable).
  final bool enabled;

  /// Placeholder shown when nothing is selected yet. Defaults to a localized
  /// "เลือกที่อยู่" / "Select address".
  final String? hint;

  /// Placeholder for the full-screen search field; falls back to a localized
  /// default.
  final String? searchHint;

  @override
  State<ThaiAddressSearchField> createState() => _ThaiAddressSearchFieldState();
}

class _ThaiAddressSearchFieldState extends State<ThaiAddressSearchField> {
  late ThaiAddressController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  void _attach(ThaiAddressController? external) {
    if (external == null) {
      _controller = ThaiAddressController();
      _ownsController = true;
    } else {
      _controller = external;
      _ownsController = false;
    }
    _controller.addListener(_onControllerChanged);
  }

  void _detach() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  /// Mirrors every controller change — whether from a picked search result or a
  /// programmatic call on the controller — to [ThaiAddressSearchField.onChanged].
  void _onControllerChanged() {
    widget.onChanged?.call(_controller.value);
  }

  @override
  void didUpdateWidget(ThaiAddressSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _attach(widget.controller);
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  bool get _isThai => widget.language == ThaiAddressLanguage.thai;

  /// The placeholder shown when nothing is selected.
  String get _hint =>
      widget.hint ?? (_isThai ? 'เลือกที่อยู่' : 'Select address');

  /// Opens the full-screen search; a picked result is committed to the
  /// controller (parent-derived from codes so the cascade guards always pass),
  /// and a `null` (dismissed) leaves the current selection untouched.
  Future<void> _openSearch() async {
    final result = await showThaiAddressSearch(
      context,
      language: widget.language,
      searchHint: widget.searchHint,
    );
    if (result == null) return;
    final (provinceCode, districtCode, subdistrictCode) = result.toCodes();
    _controller.setFromCodes(
      provinceCode: provinceCode,
      districtCode: districtCode,
      subdistrictCode: subdistrictCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThaiAddressSelection>(
      valueListenable: _controller,
      builder: (context, selection, _) {
        final summary = selection.format(language: widget.language);
        final isEmpty = summary.isEmpty;
        final text = isEmpty ? _hint : summary;

        final theme = Theme.of(context);
        final baseStyle = theme.textTheme.titleMedium;
        final textStyle = isEmpty
            ? baseStyle?.copyWith(color: theme.hintColor)
            : baseStyle;

        return InkWell(
          key: const Key('thaiAddress.searchField'),
          onTap: widget.enabled ? _openSearch : null,
          child: InputDecorator(
            decoration: widget.decoration.copyWith(enabled: widget.enabled),
            isEmpty: false,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: textStyle,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.search,
                  color: widget.enabled
                      ? theme.iconTheme.color
                      : theme.disabledColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
