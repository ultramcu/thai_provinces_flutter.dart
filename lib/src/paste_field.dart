import 'package:flutter/material.dart';
import 'package:thai_provinces/thai_provinces.dart';

import 'controller.dart';
import 'language.dart';
import 'selection.dart';

/// A paste-and-confirm address field: the user pastes (or types) a free-text
/// Thai address into a multiline box, the widget parses it live with
/// [parseThaiAddress] and shows a non-committal **preview** of what it
/// recognised, and only a deliberate tap on the confirm button writes the
/// result into the controller.
///
/// The core guarantee: **the controller is never mutated until the user taps
/// confirm.** Typing and pasting only update the local preview — so this is
/// safe to drop next to other fields sharing the same [ThaiAddressController]
/// without thrashing their selection while the user is still editing.
///
/// Built on stock Flutter widgets — no extra dependencies, no code generation.
///
/// ```dart
/// ThaiAddressPasteField(
///   controller: controller,
///   onParsed: (r) => print('leftover: ${r.remainder}'),
/// );
/// ```
class ThaiAddressPasteField extends StatefulWidget {
  /// Creates a paste-and-confirm Thai address field.
  const ThaiAddressPasteField({
    super.key,
    this.controller,
    this.language = ThaiAddressLanguage.thai,
    this.onParsed,
    this.onChanged,
    this.decoration,
    this.hintText,
    this.enabled = true,
    this.minLines = 2,
    this.maxLines = 4,
  });

  /// The controller the confirmed address is committed to.
  ///
  /// If `null`, the field creates and owns an internal controller and disposes
  /// it automatically. A caller-supplied controller is never disposed by this
  /// field — its lifecycle stays the caller's responsibility. Swapping this
  /// value at runtime detaches the old controller (disposing it only if it was
  /// the internally-owned one) and attaches the new one without committing
  /// anything to either.
  final ThaiAddressController? controller;

  /// Language for the preview text, the leftover label and the confirm button.
  /// Defaults to Thai.
  final ThaiAddressLanguage language;

  /// Called when the user confirms, with the full [ThaiAddressParseResult] —
  /// so the caller can capture the [ThaiAddressParseResult.remainder] (house
  /// number, road, …) that the committed [ThaiAddressSelection] does not carry.
  final void Function(ThaiAddressParseResult result)? onParsed;

  /// Called when the user confirms, with the committed controller value.
  final ValueChanged<ThaiAddressSelection?>? onChanged;

  /// Decoration for the paste text field. When `null` a default decoration with
  /// an [OutlineInputBorder] and the [hintText] is used.
  final InputDecoration? decoration;

  /// Hint text for the paste field. Used as the decoration's `hintText` when
  /// [decoration] does not already supply one; falls back to a language-aware
  /// default.
  final String? hintText;

  /// Whether the field (and its confirm button) are interactive.
  final bool enabled;

  /// Minimum number of visible lines for the paste text field. Defaults to 2.
  final int minLines;

  /// Maximum number of visible lines for the paste text field. Defaults to 4.
  final int maxLines;

  @override
  State<ThaiAddressPasteField> createState() => _ThaiAddressPasteFieldState();
}

class _ThaiAddressPasteFieldState extends State<ThaiAddressPasteField> {
  late ThaiAddressController _controller;
  bool _ownsController = false;

  // Owned by this State so it is disposed exactly once and never leaks.
  final TextEditingController _textController = TextEditingController();

  // The latest parse of the typed/pasted text. This is the ONLY thing typing
  // mutates — the address controller is untouched until confirm. Starts empty.
  ThaiAddressParseResult _result = const ThaiAddressParseResult();

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
  }

  void _detach() {
    if (_ownsController) {
      _controller.dispose();
    }
  }

  @override
  void didUpdateWidget(ThaiAddressPasteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _attach(widget.controller);
    }
  }

  @override
  void dispose() {
    _detach();
    _textController.dispose();
    super.dispose();
  }

  bool get _isThai => widget.language == ThaiAddressLanguage.thai;

  /// Re-parses on every keystroke/paste into the local [_result] preview. This
  /// NEVER touches [_controller] — the parse is pure and the commit is deferred
  /// to [_confirm]. Wrapped in [setState] because the preview is local state.
  void _onChangedText(String text) {
    // parseThaiAddress is pure and never throws.
    setState(() => _result = parseThaiAddress(text));
  }

  /// Commits the previewed parse to the controller and fires the callbacks.
  /// Only ever invoked from the confirm button, which is enabled solely when
  /// [_canConfirm] (a province has resolved) — so it never commits an empty
  /// selection.
  void _confirm() {
    final result = _result;
    // _confirm is only wired to the confirm button, which is enabled solely
    // when _canConfirm (a province has resolved). Assert that invariant rather
    // than guard unreachable production code.
    assert(result.province != null, '_confirm requires a resolved province');
    // Derive the consistent chain from the deepest recognised level.
    _controller.setFromCodes(
      provinceCode: result.province?.code,
      districtCode: result.district?.code,
      subdistrictCode: result.subdistrict?.code,
    );
    widget.onParsed?.call(result);
    widget.onChanged?.call(_controller.value);
  }

  /// Whether confirm is allowed: the field is enabled and the parse resolved at
  /// least a province. A bare ambiguous postcode (province `null`) parses to
  /// non-empty but must NOT enable confirm, since committing it would write an
  /// empty selection via [ThaiAddressController.setFromCodes].
  bool get _canConfirm => widget.enabled && _result.province != null;

  String get _confirmLabel => _isThai ? 'ใช้ที่อยู่นี้' : 'Use this address';
  String get _remainderLabel => _isThai ? 'บ้านเลขที่/ถนน' : 'House/road';
  String get _postcodeLabel => _isThai ? 'รหัสไปรษณีย์' : 'Postcode';
  String get _notRecognised =>
      _isThai ? 'ไม่พบที่อยู่' : "Couldn't recognize an address";
  String get _defaultHint => _isThai
      ? 'วางที่อยู่ที่นี่ เช่น 123 ถ.สุขุมวิท แขวงคลองเตย เขตคลองเตย กรุงเทพฯ 10110'
      : 'Paste an address here, e.g. 123 Sukhumvit Rd, Khlong Toei, Bangkok 10110';

  InputDecoration get _decoration {
    final base = widget.decoration ?? const InputDecoration();
    final hint = widget.hintText ?? base.hintText ?? _defaultHint;
    // Give a sensible default border when the caller passed none.
    final withBorder = widget.decoration == null
        ? base.copyWith(border: const OutlineInputBorder())
        : base;
    return withBorder.hintText == null
        ? withBorder.copyWith(hintText: hint)
        : withBorder;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('paste-input'),
          controller: _textController,
          enabled: widget.enabled,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: _decoration,
          onChanged: _onChangedText,
        ),
        const SizedBox(height: 12),
        _buildPreview(context),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            key: const ValueKey('paste-confirm'),
            onPressed: _canConfirm ? _confirm : null,
            icon: const Icon(Icons.check),
            label: Text(_confirmLabel),
          ),
        ),
      ],
    );
  }

  /// The non-committal preview of [_result]: the recognised chain, the postcode
  /// and the leftover free text — or a graceful "not recognised" hint.
  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    if (_result.isEmpty) {
      return Text(
        _notRecognised,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final chain = _previewChain();
    final rows = <Widget>[
      if (chain.isNotEmpty) Text(chain, style: theme.textTheme.titleSmall),
      if (_result.postcode != null)
        Text(
          '$_postcodeLabel: ${_result.postcode}',
          style: theme.textTheme.bodyMedium,
        ),
      if (_result.remainder.isNotEmpty)
        Text(
          '$_remainderLabel: ${_result.remainder}',
          style: theme.textTheme.bodyMedium,
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  /// The recognised province/district/subdistrict rendered for the preview, in
  /// the active language. Uses [ThaiAddressSelection.format] so it reads with
  /// the correct Thai prefixes (ตำบล/อำเภอ/จังหวัด, or แขวง/เขต for Bangkok).
  String _previewChain() {
    final selection = ThaiAddressSelection(
      province: _result.province,
      district: _result.district,
      subdistrict: _result.subdistrict,
    );
    if (selection.isEmpty) return '';
    final lang = _isThai
        ? ThaiAddressLanguage.thai
        : ThaiAddressLanguage.english;
    // The postcode is shown separately (and may be parser-reported, not the
    // resolved area's), so exclude it from the chain string here.
    return selection.format(language: lang, includePostcode: false);
  }
}
