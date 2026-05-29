import 'package:flutter/material.dart';

import 'controller.dart';
import 'language.dart';
import 'picker.dart';
import 'selection.dart';

/// A [FormField] wrapper around [ThaiAddressPicker] so a cascading Thai address
/// pick integrates with [Form], `validator`, `onSaved` and error display.
///
/// The field's value is the current [ThaiAddressSelection]. The picker's
/// changes are reported into the form state automatically; a [validator] (for
/// example, requiring [ThaiAddressSelection.isComplete]) is run by the
/// enclosing [Form] as usual, and the error text is shown beneath the fields.
class ThaiAddressFormField extends FormField<ThaiAddressSelection> {
  /// Creates a form-integrated Thai address picker.
  ///
  /// Provide a [controller] to read/drive the selection externally, or omit it
  /// to let the field own one. [initialValue] seeds the form state (and the
  /// owned controller) when no controller is supplied.
  ThaiAddressFormField({
    super.key,
    this.controller,
    ThaiAddressSelection? initialValue,
    super.validator,
    super.onSaved,
    ValueChanged<ThaiAddressSelection>? onChanged,
    ThaiAddressLanguage language = ThaiAddressLanguage.thai,
    InputDecoration decoration = const InputDecoration(),
    super.enabled,
    bool showPostcode = true,
    double spacing = 12.0,
    super.autovalidateMode,
  }) : super(
         initialValue:
             controller?.value ?? initialValue ?? ThaiAddressSelection.empty,
         builder: (FormFieldState<ThaiAddressSelection> field) {
           final state = field as _ThaiAddressFormFieldState;
           return Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               ThaiAddressPicker(
                 controller: state._controller,
                 language: language,
                 decoration: decoration,
                 enabled: field.widget.enabled,
                 showPostcode: showPostcode,
                 spacing: spacing,
                 onChanged: (value) {
                   field.didChange(value);
                   onChanged?.call(value);
                 },
               ),
               if (field.hasError)
                 Padding(
                   padding: const EdgeInsets.only(top: 8.0),
                   child: Text(
                     field.errorText ?? '',
                     style: TextStyle(
                       color: Theme.of(field.context).colorScheme.error,
                       fontSize: 12,
                     ),
                   ),
                 ),
             ],
           );
         },
       );

  /// An external controller, or `null` to own one internally.
  final ThaiAddressController? controller;

  @override
  FormFieldState<ThaiAddressSelection> createState() =>
      _ThaiAddressFormFieldState();
}

class _ThaiAddressFormFieldState extends FormFieldState<ThaiAddressSelection> {
  ThaiAddressFormField get _field => widget as ThaiAddressFormField;

  late ThaiAddressController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    final external = _field.controller;
    if (external == null) {
      _controller = ThaiAddressController(initial: value);
      _ownsController = true;
    } else {
      _controller = external;
      _ownsController = false;
    }
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (_controller.value != value) {
      didChange(_controller.value);
    }
  }

  @override
  void didChange(ThaiAddressSelection? value) {
    super.didChange(value);
    final v = value ?? ThaiAddressSelection.empty;
    if (_controller.value != v) {
      _controller.value = v;
    }
  }

  @override
  void reset() {
    super.reset();
    _controller.value = widget.initialValue ?? ThaiAddressSelection.empty;
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }
}
