import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thai_provinces/thai_provinces.dart';

import 'controller.dart';
import 'language.dart';
import 'selection.dart';

/// A postcode-first address field: the user types a 5-digit Thai postal code
/// and the address auto-fills as far as the code is unambiguous, via
/// [ThaiAddressController.setPostcode]. The province (and district) fill only
/// when every matching subdistrict shares them — most postcodes do, but ~18%
/// span several districts and a few span several provinces — and the
/// subdistrict fills when the postcode is 1:1. When several subdistricts match
/// and [showSubdistrictChooser] is `true`, an inline chooser appears (even if
/// no parent could be pinned) and the pick resolves the whole address.
///
/// Built on stock Flutter widgets — no extra dependencies, no code generation.
/// Works inside a `Form`.
class ThaiPostcodeField extends StatefulWidget {
  /// Creates a postcode-first address field.
  const ThaiPostcodeField({
    super.key,
    this.controller,
    this.onChanged,
    this.decoration = const InputDecoration(),
    this.enabled = true,
    this.language = ThaiAddressLanguage.thai,
    this.showSubdistrictChooser = true,
  });

  /// The controller holding the current selection. If `null`, the field
  /// creates and owns an internal controller and disposes it automatically.
  final ThaiAddressController? controller;

  /// Called whenever the selection changes, with the new value.
  final ValueChanged<ThaiAddressSelection>? onChanged;

  /// Decoration applied to the postcode text field.
  final InputDecoration decoration;

  /// Whether the field is interactive.
  final bool enabled;

  /// Language used for the inline subdistrict-chooser labels. Defaults to Thai.
  final ThaiAddressLanguage language;

  /// Whether to show an inline subdistrict chooser when a postcode maps to
  /// several subdistricts. Defaults to `true`.
  final bool showSubdistrictChooser;

  @override
  State<ThaiPostcodeField> createState() => _ThaiPostcodeFieldState();
}

class _ThaiPostcodeFieldState extends State<ThaiPostcodeField> {
  late ThaiAddressController _controller;
  bool _ownsController = false;

  // The TextEditingController for the 5-digit postcode entry. Owned by this
  // State so it is disposed exactly once and never leaks across rebuilds.
  final TextEditingController _textController = TextEditingController();

  // The postcode currently driving the selection, kept so the inline chooser
  // can list `byPostcode(_activePostcode)` candidates. A controller carries a
  // postcode only via a chosen subdistrict, so while the subdistrict is still
  // ambiguous (province + district set, subdistrict null) we need our own copy
  // of the typed code to rebuild the candidate list.
  int? _activePostcode;

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
    _seedFromController();
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

  /// Reflects any pre-existing controller selection into the field on wire-up:
  /// shows the postcode when one is derivable and seeds [_activePostcode] so
  /// the chooser can repopulate without the user retyping.
  void _seedFromController() {
    final selection = _controller.value;
    final code = _postcodeOf(selection);
    if (code != null) {
      _activePostcode = code;
      _textController.text = code.toString();
    }
  }

  /// The 5-digit postcode implied by a [selection]: the chosen subdistrict's
  /// postcode, or — when the subdistrict is still ambiguous — the code shared
  /// by every subdistrict of the chosen district, if they all share one.
  int? _postcodeOf(ThaiAddressSelection selection) {
    final sub = selection.subdistrict;
    if (sub != null) return sub.postcode;
    final district = selection.district;
    if (district == null) return null;
    final subs = district.subdistricts;
    if (subs.isEmpty) return null;
    final first = subs.first.postcode;
    return subs.every((s) => s.postcode == first) ? first : null;
  }

  /// Mirrors every controller change — from a chooser pick or a programmatic
  /// call — to [ThaiPostcodeField.onChanged], and keeps the postcode text in
  /// sync when the selection is changed from the outside.
  void _onControllerChanged() {
    widget.onChanged?.call(_controller.value);
    final code = _postcodeOf(_controller.value);
    if (code != null) {
      _activePostcode = code;
      final text = code.toString();
      if (_textController.text != text) {
        _textController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    } else if (_controller.value.isEmpty) {
      // An empty selection from an *ambiguous* postcode — one that spans
      // several provinces, so setPostcode could pin no level at all — must NOT
      // wipe the active postcode: the chooser still needs it to list the
      // candidates. Only reset when there is no valid active postcode (the
      // field was cleared, or an unknown code was typed).
      final active = _activePostcode;
      if (active == null || byPostcode(active).isEmpty) {
        _activePostcode = null;
        if (_textController.text.isNotEmpty) {
          _textController.clear();
        }
      }
    }
  }

  @override
  void didUpdateWidget(ThaiPostcodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _attach(widget.controller);
      _seedFromController();
    }
  }

  @override
  void dispose() {
    _detach();
    _textController.dispose();
    super.dispose();
  }

  bool get _isThai => widget.language == ThaiAddressLanguage.thai;

  String get _defaultPostcodeLabel => _isThai ? 'รหัสไปรษณีย์' : 'Postcode';
  String get _defaultSubdistrictLabel => _isThai ? 'ตำบล/แขวง' : 'Subdistrict';

  /// Resolves the typed [text] into the controller. A complete, well-formed
  /// 5-digit code drives [ThaiAddressController.setPostcode]; anything shorter
  /// leaves the selection untouched (so partial typing doesn't thrash it),
  /// while clearing the field clears the selection.
  ///
  /// [_activePostcode] (which drives the chooser candidates) is local state, so
  /// its changes are wrapped in [setState]. This also covers the case where a
  /// multi-province postcode resolves to an *empty* selection identical to the
  /// current one: the controller does not notify (value equality), so the
  /// chooser would never appear without this explicit rebuild.
  void _onChangedText(String text) {
    if (text.isEmpty) {
      setState(() => _activePostcode = null);
      _controller.clear();
      return;
    }
    if (text.length < 5) return;
    final code = int.tryParse(text);
    if (code == null) return;
    setState(() => _activePostcode = code);
    _controller.setPostcode(code);
  }

  /// The subdistrict candidates for the active postcode, used to populate the
  /// inline chooser. Empty when no postcode is active.
  List<Subdistrict> get _candidates {
    final code = _activePostcode;
    if (code == null) return const [];
    return byPostcode(code);
  }

  /// Whether the inline subdistrict chooser should be shown: enabled by the
  /// caller, the subdistrict is still unset, and the active postcode maps to
  /// more than one subdistrict (which may even span several districts).
  bool _shouldShowChooser(ThaiAddressSelection selection) {
    if (!widget.showSubdistrictChooser) return false;
    // No province/district pin is required: a postcode that spans several
    // districts (or provinces) leaves those levels null, yet still needs the
    // chooser to disambiguate over the full candidate set.
    if (selection.subdistrict != null) return false;
    return _candidates.length > 1;
  }

  InputDecoration get _postcodeDecoration {
    final base = widget.decoration;
    return base.labelText != null
        ? base
        : base.copyWith(labelText: _defaultPostcodeLabel);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThaiAddressSelection>(
      valueListenable: _controller,
      builder: (context, selection, _) {
        final children = <Widget>[
          TextField(
            key: const Key('thaiAddress.postcodeInput'),
            controller: _textController,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.postalCode],
            maxLength: 5,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            decoration: _postcodeDecoration,
            onChanged: _onChangedText,
          ),
        ];

        if (_shouldShowChooser(selection)) {
          children
            ..add(const SizedBox(height: 12))
            ..add(_buildChooser(selection));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  Widget _buildChooser(ThaiAddressSelection selection) {
    final candidates = _candidates;
    return DropdownButtonFormField<Subdistrict>(
      key: const Key('thaiAddress.postcodeSubdistrict'),
      initialValue: selection.subdistrict,
      isExpanded: true,
      decoration: InputDecoration(labelText: _defaultSubdistrictLabel),
      items: [
        for (final s in candidates)
          DropdownMenuItem<Subdistrict>(
            value: s,
            child: Text(widget.language.labelOfSubdistrict(s)),
          ),
      ],
      // Commit the full triple from the picked subdistrict's code so it works
      // even when the postcode spans several districts/provinces (where
      // setPostcode could not pin a parent, so setSubdistrict's guard would
      // reject the pick). fromCodes derives the consistent district + province.
      onChanged: widget.enabled
          ? (s) {
              if (s != null) _controller.setFromCodes(subdistrictCode: s.code);
            }
          : null,
    );
  }
}
