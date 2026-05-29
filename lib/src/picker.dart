import 'package:flutter/material.dart';
import 'package:thai_provinces/thai_provinces.dart';

import 'controller.dart';
import 'language.dart';
import 'selection.dart';

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
    this.enabled = true,
    this.showPostcode = true,
    this.spacing = 12.0,
    this.provinceLabel,
    this.districtLabel,
    this.subdistrictLabel,
    this.postcodeLabel,
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
    _controller.addListener(_onControllerChanged);
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThaiAddressSelection>(
      valueListenable: _controller,
      builder: (context, selection, _) {
        final provinces = _buildProvinces();
        final districts = _buildDistricts(selection);
        final subdistricts = _buildSubdistricts(selection);

        final children = <Widget>[
          DropdownButtonFormField<Province>(
            key: const Key('thaiAddress.province'),
            initialValue: selection.province,
            isExpanded: true,
            decoration: _decorationFor(
              widget.provinceLabel,
              _defaultProvinceLabel,
            ),
            items: provinces,
            onChanged: widget.enabled ? _controller.setProvince : null,
          ),
          SizedBox(height: widget.spacing),
          DropdownButtonFormField<District>(
            key: const Key('thaiAddress.district'),
            initialValue: selection.district,
            isExpanded: true,
            decoration: _decorationFor(
              widget.districtLabel,
              _defaultDistrictLabel,
            ),
            items: districts,
            onChanged: widget.enabled && selection.province != null
                ? _controller.setDistrict
                : null,
          ),
          SizedBox(height: widget.spacing),
          DropdownButtonFormField<Subdistrict>(
            key: const Key('thaiAddress.subdistrict'),
            initialValue: selection.subdistrict,
            isExpanded: true,
            decoration: _decorationFor(
              widget.subdistrictLabel,
              _defaultSubdistrictLabel,
            ),
            items: subdistricts,
            onChanged: widget.enabled && selection.district != null
                ? _controller.setSubdistrict
                : null,
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

  List<DropdownMenuItem<Province>> _buildProvinces() {
    return [
      for (final p in provinces())
        DropdownMenuItem<Province>(
          value: p,
          child: Text(widget.language.labelOf(p)),
        ),
    ];
  }

  List<DropdownMenuItem<District>> _buildDistricts(
    ThaiAddressSelection selection,
  ) {
    final province = selection.province;
    if (province == null) return const [];
    return [
      for (final d in province.districts)
        DropdownMenuItem<District>(
          value: d,
          child: Text(widget.language.labelOfDistrict(d)),
        ),
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
          child: Text(widget.language.labelOfSubdistrict(s)),
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
      decoration: _decorationFor(widget.postcodeLabel, _defaultPostcodeLabel),
    );
  }
}
