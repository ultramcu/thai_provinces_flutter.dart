import 'package:flutter/material.dart';
import 'package:thai_provinces/thai_provinces.dart';

import 'controller.dart';
import 'language.dart';
import 'selection.dart';

/// Which level a [ThaiAddressFieldBuilder] is being asked to build.
enum ThaiAddressLevel {
  /// The province (จังหวัด) field.
  province,

  /// The district (อำเภอ/เขต) field.
  district,

  /// The subdistrict (ตำบล/แขวง) field.
  subdistrict,
}

/// Everything a custom field needs to render one level of a [ThaiAddressPicker].
///
/// [options] holds the selectable area models for [level] (`Province`s,
/// `District`s or `Subdistrict`s); [selected] is the current one (or `null`);
/// call [onSelected] with the picked option (cast to the level's type) — the
/// picker handles the cascade. [label] is the resolved field label.
class ThaiAddressFieldScope {
  /// Creates a field scope (constructed by the picker).
  const ThaiAddressFieldScope({
    required this.level,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.enabled,
    required this.label,
  });

  /// The level being built.
  final ThaiAddressLevel level;

  /// The selectable options for [level] (`Province`/`District`/`Subdistrict`).
  final List<Object> options;

  /// The currently-selected option, or `null`.
  final Object? selected;

  /// Commit a selection (pass the chosen option, or `null` to clear).
  final ValueChanged<Object?> onSelected;

  /// Whether this field should be interactive.
  final bool enabled;

  /// The resolved label for this field.
  final String label;
}

/// Builds a custom widget for one level of the picker; return `null` to fall
/// back to the default dropdown for that level.
typedef ThaiAddressFieldBuilder =
    Widget? Function(BuildContext context, ThaiAddressFieldScope scope);

/// Overrides the display label for an area model (a `Province`, `District` or
/// `Subdistrict`); return the string to show instead of the language default.
typedef ThaiAddressLabelBuilder = String Function(Object area);

/// A drop-in cascading Thai address picker: three [DropdownButtonFormField]s
/// (province → district → subdistrict) plus an optional read-only postcode
/// field, all driven by a [ThaiAddressController].
///
/// The package depends on nothing but Flutter and `thai_provinces` — there is
/// no state-management lock-in (no provider/bloc/riverpod) and no code
/// generation. State is held in a plain [ValueNotifier]
/// ([ThaiAddressController]).
///
/// Each child dropdown is disabled until its parent is chosen. The postcode is
/// auto-filled from the chosen subdistrict. The widget works inside a [Form];
/// for validation use [ThaiAddressFormField].
class ThaiAddressPicker extends StatefulWidget {
  /// Creates a cascading Thai address picker.
  const ThaiAddressPicker({
    super.key,
    this.controller,
    this.onChanged,
    this.language = ThaiAddressLanguage.thai,
    this.decoration = const InputDecoration(),
    this.style,
    this.dropdownColor,
    this.borderRadius,
    this.icon,
    this.iconEnabledColor,
    this.menuMaxHeight,
    this.enabled = true,
    this.showPostcode = true,
    this.spacing = 12.0,
    this.provinceLabel,
    this.districtLabel,
    this.subdistrictLabel,
    this.postcodeLabel,
    this.initialCodes,
    this.fieldBuilder,
    this.labelBuilder,
  });

  /// The controller holding the current selection. If `null`, the widget
  /// creates and owns an internal controller and disposes it automatically.
  final ThaiAddressController? controller;

  /// Called whenever the selection changes, with the new value.
  final ValueChanged<ThaiAddressSelection>? onChanged;

  /// Language used for the dropdown option labels. Defaults to
  /// [ThaiAddressLanguage.thai].
  final ThaiAddressLanguage language;

  /// Base [InputDecoration] applied to each field. A per-field `labelText`
  /// (see [provinceLabel] etc.) is layered on top via `copyWith` when not
  /// already supplied.
  final InputDecoration decoration;

  /// Text style for the selected item shown in each dropdown's button.
  /// Forwarded as `DropdownButtonFormField.style`; `null` keeps the default.
  final TextStyle? style;

  /// Background color of each dropdown's open menu. Forwarded as
  /// `DropdownButtonFormField.dropdownColor`; `null` keeps the default.
  final Color? dropdownColor;

  /// Corner radius of each dropdown's open menu. Forwarded as
  /// `DropdownButtonFormField.borderRadius`; `null` keeps the default.
  final BorderRadius? borderRadius;

  /// Trailing widget shown for each dropdown (e.g. the down arrow). Forwarded
  /// as `DropdownButtonFormField.icon`; `null` keeps the default chevron.
  final Widget? icon;

  /// Color applied to each dropdown's [icon] when the field is enabled.
  /// Forwarded as `DropdownButtonFormField.iconEnabledColor`; `null` keeps the
  /// default.
  final Color? iconEnabledColor;

  /// Maximum height of each dropdown's open menu, in logical pixels. Forwarded
  /// as `DropdownButtonFormField.menuMaxHeight`; `null` keeps the default.
  final double? menuMaxHeight;

  /// Whether the whole picker is interactive. When `false`, all fields are
  /// disabled regardless of selection state.
  final bool enabled;

  /// Whether to show the read-only postcode field. Defaults to `true`.
  final bool showPostcode;

  /// Vertical gap between the fields, in logical pixels. Defaults to `12`.
  final double spacing;

  /// Optional label for the province field. Defaults to a language-appropriate
  /// label when the [decoration] has none.
  final String? provinceLabel;

  /// Optional label for the district field.
  final String? districtLabel;

  /// Optional label for the subdistrict field.
  final String? subdistrictLabel;

  /// Optional label for the postcode field.
  final String? postcodeLabel;

  /// Optional initial selection given as official DOPA codes
  /// `(provinceCode, districtCode, subdistrictCode)`; applied once when the
  /// widget is first created via [ThaiAddressSelection.fromCodes]. Ignored when
  /// a [controller] is supplied that already holds a non-empty selection.
  /// Wired by the picker-integration dev.
  final (int? provinceCode, int? districtCode, int? subdistrictCode)?
  initialCodes;

  /// Optional builder to render a custom widget per level instead of the
  /// default dropdown (e.g. an autocomplete, a Cupertino picker or a
  /// bottom-sheet trigger), while the picker keeps the cascade/clear/postcode
  /// logic. Return `null` for a level to use the default. Wired by the dev.
  final ThaiAddressFieldBuilder? fieldBuilder;

  /// Optional override for an option's display label (given a `Province`,
  /// `District` or `Subdistrict`); falls back to the [language] default when
  /// `null`. Wired by the dev.
  final ThaiAddressLabelBuilder? labelBuilder;

  @override
  State<ThaiAddressPicker> createState() => _ThaiAddressPickerState();
}

class _ThaiAddressPickerState extends State<ThaiAddressPicker> {
  late ThaiAddressController _controller;
  bool _ownsController = false;

  // A single, State-owned controller for the read-only postcode field. Held
  // here (not rebuilt in build()) so it is disposed exactly once and never
  // leaks across rebuilds.
  final TextEditingController _postcodeController = TextEditingController();

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
    _maybeSeedInitialCodes();
    _controller.addListener(_onControllerChanged);
  }

  /// Applies [ThaiAddressPicker.initialCodes] to the controller exactly once,
  /// at attach time, when it is non-null and the controller currently holds an
  /// empty selection. This seeds the internal controller, or a supplied
  /// controller that is still empty, while never clobbering a supplied
  /// controller that already holds a non-empty selection. Seeded before the
  /// listener is added so it does not fire [ThaiAddressPicker.onChanged] during
  /// [initState].
  void _maybeSeedInitialCodes() {
    final codes = widget.initialCodes;
    if (codes == null || !_controller.value.isEmpty) return;
    final (provinceCode, districtCode, subdistrictCode) = codes;
    _controller.value = ThaiAddressSelection.fromCodes(
      provinceCode: provinceCode,
      districtCode: districtCode,
      subdistrictCode: subdistrictCode,
    );
  }

  void _detach() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  /// Mirrors every controller change — whether from a dropdown tap or a
  /// programmatic call on the controller — to [ThaiAddressPicker.onChanged],
  /// so the callback is a single source of truth for selection changes.
  void _onControllerChanged() => widget.onChanged?.call(_controller.value);

  @override
  void didUpdateWidget(ThaiAddressPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _attach(widget.controller);
    }
  }

  @override
  void dispose() {
    _detach();
    _postcodeController.dispose();
    super.dispose();
  }

  bool _isThai(ThaiAddressLanguage l) => l == ThaiAddressLanguage.thai;

  String get _defaultProvinceLabel =>
      _isThai(widget.language) ? 'จังหวัด' : 'Province';
  String get _defaultDistrictLabel =>
      _isThai(widget.language) ? 'อำเภอ/เขต' : 'District';
  String get _defaultSubdistrictLabel =>
      _isThai(widget.language) ? 'ตำบล/แขวง' : 'Subdistrict';
  String get _defaultPostcodeLabel =>
      _isThai(widget.language) ? 'รหัสไปรษณีย์' : 'Postcode';

  InputDecoration _decorationFor(String? explicit, String fallback) {
    final base = widget.decoration;
    if (base.labelText != null || explicit == null) {
      // Honor a caller-set labelText; otherwise apply the explicit/default.
      return base.labelText != null ? base : base.copyWith(labelText: fallback);
    }
    return base.copyWith(labelText: explicit);
  }

  /// Resolves the display text for an area option: a caller-supplied
  /// [ThaiAddressPicker.labelBuilder] wins, otherwise the [language] default.
  String _labelOfProvince(Province p) =>
      widget.labelBuilder?.call(p) ?? widget.language.labelOf(p);
  String _labelOfDistrict(District d) =>
      widget.labelBuilder?.call(d) ?? widget.language.labelOfDistrict(d);
  String _labelOfSubdistrict(Subdistrict s) =>
      widget.labelBuilder?.call(s) ?? widget.language.labelOfSubdistrict(s);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThaiAddressSelection>(
      valueListenable: _controller,
      builder: (context, selection, _) {
        final children = <Widget>[
          _buildField(
            context: context,
            level: ThaiAddressLevel.province,
            options: provinces().cast<Object>(),
            selected: selection.province,
            enabled: widget.enabled,
            label: widget.provinceLabel ?? _defaultProvinceLabel,
            decoration: _decorationFor(
              widget.provinceLabel,
              _defaultProvinceLabel,
            ),
            onSelected: (area) => _controller.setProvince(area as Province?),
            defaultField: () => DropdownButtonFormField<Province>(
              key: const Key('thaiAddress.province'),
              initialValue: selection.province,
              isExpanded: true,
              decoration: _decorationFor(
                widget.provinceLabel,
                _defaultProvinceLabel,
              ),
              items: _buildProvinces(),
              style: widget.style,
              dropdownColor: widget.dropdownColor,
              borderRadius: widget.borderRadius,
              icon: widget.icon,
              iconEnabledColor: widget.iconEnabledColor,
              menuMaxHeight: widget.menuMaxHeight,
              onChanged: widget.enabled ? _controller.setProvince : null,
            ),
          ),
          SizedBox(height: widget.spacing),
          _buildField(
            context: context,
            level: ThaiAddressLevel.district,
            options:
                selection.province?.districts.cast<Object>() ??
                const <Object>[],
            selected: selection.district,
            enabled: widget.enabled && selection.province != null,
            label: widget.districtLabel ?? _defaultDistrictLabel,
            decoration: _decorationFor(
              widget.districtLabel,
              _defaultDistrictLabel,
            ),
            onSelected: (area) => _controller.setDistrict(area as District?),
            defaultField: () => DropdownButtonFormField<District>(
              key: const Key('thaiAddress.district'),
              initialValue: selection.district,
              isExpanded: true,
              decoration: _decorationFor(
                widget.districtLabel,
                _defaultDistrictLabel,
              ),
              items: _buildDistricts(selection),
              style: widget.style,
              dropdownColor: widget.dropdownColor,
              borderRadius: widget.borderRadius,
              icon: widget.icon,
              iconEnabledColor: widget.iconEnabledColor,
              menuMaxHeight: widget.menuMaxHeight,
              onChanged: widget.enabled && selection.province != null
                  ? _controller.setDistrict
                  : null,
            ),
          ),
          SizedBox(height: widget.spacing),
          _buildField(
            context: context,
            level: ThaiAddressLevel.subdistrict,
            options:
                selection.district?.subdistricts.cast<Object>() ??
                const <Object>[],
            selected: selection.subdistrict,
            enabled: widget.enabled && selection.district != null,
            label: widget.subdistrictLabel ?? _defaultSubdistrictLabel,
            decoration: _decorationFor(
              widget.subdistrictLabel,
              _defaultSubdistrictLabel,
            ),
            onSelected: (area) =>
                _controller.setSubdistrict(area as Subdistrict?),
            defaultField: () => DropdownButtonFormField<Subdistrict>(
              key: const Key('thaiAddress.subdistrict'),
              initialValue: selection.subdistrict,
              isExpanded: true,
              decoration: _decorationFor(
                widget.subdistrictLabel,
                _defaultSubdistrictLabel,
              ),
              items: _buildSubdistricts(selection),
              style: widget.style,
              dropdownColor: widget.dropdownColor,
              borderRadius: widget.borderRadius,
              icon: widget.icon,
              iconEnabledColor: widget.iconEnabledColor,
              menuMaxHeight: widget.menuMaxHeight,
              onChanged: widget.enabled && selection.district != null
                  ? _controller.setSubdistrict
                  : null,
            ),
          ),
        ];

        if (widget.showPostcode) {
          children
            ..add(SizedBox(height: widget.spacing))
            ..add(_buildPostcode(selection));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  /// Builds one level: hands a [ThaiAddressFieldScope] to
  /// [ThaiAddressPicker.fieldBuilder] and uses its widget when it returns one,
  /// otherwise falls back to [defaultField] (the default dropdown).
  Widget _buildField({
    required BuildContext context,
    required ThaiAddressLevel level,
    required List<Object> options,
    required Object? selected,
    required ValueChanged<Object?> onSelected,
    required bool enabled,
    required String label,
    required InputDecoration decoration,
    required Widget Function() defaultField,
  }) {
    final builder = widget.fieldBuilder;
    if (builder != null) {
      final custom = builder(
        context,
        ThaiAddressFieldScope(
          level: level,
          options: options,
          selected: selected,
          onSelected: onSelected,
          enabled: enabled,
          label: label,
        ),
      );
      if (custom != null) return custom;
    }
    return defaultField();
  }

  List<DropdownMenuItem<Province>> _buildProvinces() {
    return [
      for (final p in provinces())
        DropdownMenuItem<Province>(value: p, child: Text(_labelOfProvince(p))),
    ];
  }

  List<DropdownMenuItem<District>> _buildDistricts(
    ThaiAddressSelection selection,
  ) {
    final province = selection.province;
    if (province == null) return const [];
    return [
      for (final d in province.districts)
        DropdownMenuItem<District>(value: d, child: Text(_labelOfDistrict(d))),
    ];
  }

  List<DropdownMenuItem<Subdistrict>> _buildSubdistricts(
    ThaiAddressSelection selection,
  ) {
    final district = selection.district;
    if (district == null) return const [];
    return [
      for (final s in district.subdistricts)
        DropdownMenuItem<Subdistrict>(
          value: s,
          child: Text(_labelOfSubdistrict(s)),
        ),
    ];
  }

  Widget _buildPostcode(ThaiAddressSelection selection) {
    // Reuse the single State-owned controller; just refresh its text. The
    // field is disabled, so mutating it during build is safe and loop-free.
    _postcodeController.text = selection.postcode?.toString() ?? '';
    return TextField(
      key: const Key('thaiAddress.postcode'),
      enabled: false,
      controller: _postcodeController,
      autofillHints: const [AutofillHints.postalCode],
      decoration: _decorationFor(widget.postcodeLabel, _defaultPostcodeLabel),
    );
  }
}
