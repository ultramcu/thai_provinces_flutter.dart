import 'package:flutter/material.dart';

import 'controller.dart';
import 'language.dart';
import 'selection.dart';
import 'suggestions.dart';

/// A single type-ahead field that resolves a free-text Thai address query to a
/// full [ThaiAddressSelection].
///
/// The user types a Thai/English subdistrict (or district/province) name, or a
/// postal-code prefix; matching [ThaiAddressSuggestion]s (from
/// [thaiAddressSuggestions], unless [optionsBuilder] overrides it) are shown,
/// and picking one cascades into the shared [controller] — making the
/// controller the single source of truth, exactly like [ThaiAddressPicker].
///
/// Built on Flutter's stock `Autocomplete`; no extra dependencies, no code
/// generation. Works inside a `Form`.
class ThaiAddressAutocompleteField extends StatefulWidget {
  /// Creates a Thai address autocomplete field.
  const ThaiAddressAutocompleteField({
    super.key,
    this.controller,
    this.onChanged,
    this.language = ThaiAddressLanguage.thai,
    this.decoration = const InputDecoration(),
    this.enabled = true,
    this.maxOptions = 20,
    this.optionsBuilder,
    this.displayStringFor,
  });

  /// The controller holding the current selection. If `null`, the field
  /// creates and owns an internal controller and disposes it automatically.
  final ThaiAddressController? controller;

  /// Called whenever the selection changes, with the new value.
  final ValueChanged<ThaiAddressSelection>? onChanged;

  /// Language used for the suggestion/breadcrumb labels. Defaults to Thai.
  final ThaiAddressLanguage language;

  /// Decoration applied to the text field.
  final InputDecoration decoration;

  /// Whether the field is interactive.
  final bool enabled;

  /// Maximum number of suggestions to show. Defaults to 20.
  final int maxOptions;

  /// Optional override producing the suggestion list for a [query]. Defaults
  /// to [thaiAddressSuggestions]`(query, limit: maxOptions)`.
  final List<ThaiAddressSuggestion> Function(String query)? optionsBuilder;

  /// Optional override for the text shown for a suggestion. Defaults to
  /// `suggestion.display(language)`.
  final String Function(ThaiAddressSuggestion suggestion)? displayStringFor;

  @override
  State<ThaiAddressAutocompleteField> createState() =>
      _ThaiAddressAutocompleteFieldState();
}

class _ThaiAddressAutocompleteFieldState
    extends State<ThaiAddressAutocompleteField> {
  late ThaiAddressController _controller;
  bool _ownsController = false;

  // The TextEditingController for the inner field is owned by the stock
  // Autocomplete and handed to us in fieldViewBuilder. We hold a reference so
  // we can keep its text in sync with programmatic controller changes.
  TextEditingController? _textController;

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

  /// Mirrors every controller change — whether from picking an option or from a
  /// programmatic call on the controller — to
  /// [ThaiAddressAutocompleteField.onChanged], and keeps the field text in sync
  /// with the current selection on a best-effort basis.
  void _onControllerChanged() {
    widget.onChanged?.call(_controller.value);
    _syncFieldText();
  }

  /// Reflects the controller's current selection into the inner field text.
  ///
  /// When a complete selection is present its breadcrumb is shown; when the
  /// selection is cleared the field is emptied. This is best-effort: the field
  /// text is only authoritative while the user is typing, so we avoid clobbering
  /// it for partial selections (which the autocomplete never produces itself).
  void _syncFieldText() {
    final field = _textController;
    if (field == null) return;
    final selection = _controller.value;
    final String desired;
    if (selection.isComplete) {
      desired = _displayFor(
        ThaiAddressSuggestion(
          province: selection.province!,
          district: selection.district!,
          subdistrict: selection.subdistrict!,
        ),
      );
    } else if (selection.isEmpty) {
      desired = '';
    } else {
      // Partial selection: leave whatever the user has typed untouched.
      return;
    }
    if (field.text != desired) {
      field.value = TextEditingValue(
        text: desired,
        selection: TextSelection.collapsed(offset: desired.length),
      );
    }
  }

  @override
  void didUpdateWidget(ThaiAddressAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _attach(widget.controller);
      _syncFieldText();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  /// The label for a suggestion, honoring [ThaiAddressAutocompleteField.displayStringFor].
  String _displayFor(ThaiAddressSuggestion suggestion) =>
      (widget.displayStringFor ?? (s) => s.display(widget.language))(
        suggestion,
      );

  /// Produces the suggestion list for [query], honoring
  /// [ThaiAddressAutocompleteField.optionsBuilder].
  List<ThaiAddressSuggestion> _optionsFor(String query) =>
      (widget.optionsBuilder ??
      (q) => thaiAddressSuggestions(q, limit: widget.maxOptions))(query);

  /// The accessibility label announced for the search field.
  ///
  /// Honors an explicit `labelText`/`hintText` from the caller's [decoration];
  /// otherwise falls back to a language-appropriate default so screen readers
  /// always have something meaningful to announce.
  String get _semanticsLabel {
    final decoration = widget.decoration;
    return decoration.labelText ?? decoration.hintText ?? _defaultLabel;
  }

  String get _defaultLabel => widget.language == ThaiAddressLanguage.thai
      ? 'ค้นหาที่อยู่'
      : 'Search address';

  /// Commits a picked suggestion to the controller parent-first, so the
  /// cascade-consistency guards on the setters always pass.
  void _onSelected(ThaiAddressSuggestion suggestion) {
    _controller
      ..setProvince(suggestion.province)
      ..setDistrict(suggestion.district)
      ..setSubdistrict(suggestion.subdistrict);
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<ThaiAddressSuggestion>(
      displayStringForOption: _displayFor,
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) {
          return const Iterable<ThaiAddressSuggestion>.empty();
        }
        return _optionsFor(value.text);
      },
      onSelected: _onSelected,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            // Track the Autocomplete-owned text controller so programmatic
            // controller changes can be mirrored back into the field.
            if (!identical(_textController, textEditingController)) {
              _textController = textEditingController;
              // Reflect any pre-existing selection on first wire-up.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _syncFieldText();
              });
            }
            return Semantics(
              textField: true,
              label: _semanticsLabel,
              child: TextField(
                key: const Key('thaiAddress.autocomplete'),
                controller: textEditingController,
                focusNode: focusNode,
                enabled: widget.enabled,
                autofillHints: const [AutofillHints.fullStreetAddress],
                decoration: widget.decoration,
                onSubmitted: (_) => onFieldSubmitted(),
              ),
            );
          },
    );
  }
}
