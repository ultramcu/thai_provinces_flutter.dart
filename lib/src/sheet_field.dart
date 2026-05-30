import 'package:flutter/material.dart';

import 'controller.dart';
import 'language.dart';
import 'selection.dart';
import 'sheet.dart';

/// A compact, single-line address field: it shows the current selection as one
/// read-only summary line (via [ThaiAddressSelection.format]) and, when tapped,
/// opens a modal bottom-sheet picker ([showThaiAddressSheet]); confirming the
/// sheet commits the new selection to the (shared or internal) controller.
///
/// This is the dense-checkout pattern (one tappable line that expands to a
/// sheet) — ideal when three full-width dropdowns would crowd the form. Built
/// on stock Flutter widgets; no extra dependencies. Works inside a `Form` via
/// the controller.
class ThaiAddressSheetField extends StatefulWidget {
  /// Creates a sheet-style Thai address field.
  const ThaiAddressSheetField({
    super.key,
    this.controller,
    this.onChanged,
    this.language = ThaiAddressLanguage.thai,
    this.decoration = const InputDecoration(),
    this.enabled = true,
    this.hint,
    this.title,
    this.confirmLabel,
  });

  /// The controller holding the current selection. If `null`, the field creates
  /// and owns an internal controller and disposes it automatically.
  final ThaiAddressController? controller;

  /// Called whenever the selection changes (after a confirmed sheet edit or a
  /// programmatic controller change).
  final ValueChanged<ThaiAddressSelection>? onChanged;

  /// Language for the summary line and the picker inside the sheet.
  final ThaiAddressLanguage language;

  /// Decoration for the collapsed summary field (label, border, icon, …).
  final InputDecoration decoration;

  /// Whether the field is interactive (tappable).
  final bool enabled;

  /// Placeholder shown when nothing is selected yet. Defaults to a localized
  /// "เลือกที่อยู่" / "Select address".
  final String? hint;

  /// Sheet heading; falls back to a localized default.
  final String? title;

  /// Confirm-button label inside the sheet; falls back to a localized default.
  final String? confirmLabel;

  @override
  State<ThaiAddressSheetField> createState() => _ThaiAddressSheetFieldState();
}

class _ThaiAddressSheetFieldState extends State<ThaiAddressSheetField> {
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

  /// Mirrors every controller change — whether from a confirmed sheet edit or a
  /// programmatic call on the controller — to [ThaiAddressSheetField.onChanged].
  void _onControllerChanged() {
    widget.onChanged?.call(_controller.value);
  }

  @override
  void didUpdateWidget(ThaiAddressSheetField oldWidget) {
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

  /// Opens the sheet seeded with the current selection; a confirmed result is
  /// committed to the controller (parent-derived from codes so the cascade
  /// guards always pass), and a `null` (cancel/dismiss) leaves it untouched.
  Future<void> _openSheet() async {
    final result = await showThaiAddressSheet(
      context,
      initial: _controller.value,
      language: widget.language,
      title: widget.title,
      confirmLabel: widget.confirmLabel,
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
          key: const Key('thaiAddress.sheetField'),
          onTap: widget.enabled ? _openSheet : null,
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
                  Icons.chevron_right,
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
