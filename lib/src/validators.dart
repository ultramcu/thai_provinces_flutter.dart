import 'package:flutter/widgets.dart';

import 'language.dart';
import 'selection.dart';

/// Ready-made `FormField` validators for a [ThaiAddressSelection].
///
/// Use with [ThaiAddressFormField] (or any `FormField<ThaiAddressSelection>`):
///
/// ```dart
/// ThaiAddressFormField(
///   validator: ThaiAddressValidators.required(language: ThaiAddressLanguage.thai),
/// )
/// ```
class ThaiAddressValidators {
  ThaiAddressValidators._();

  /// A validator that requires a complete selection (province + district +
  /// subdistrict).
  ///
  /// The returned [FormFieldValidator] yields `null` (valid) only when the
  /// value is non-null and [ThaiAddressSelection.isComplete]; otherwise it
  /// returns an error message. Pass [message] to override the default text;
  /// when omitted, a default localized to [language] is used:
  ///
  /// | [language]                       | default message                                       |
  /// |----------------------------------|-------------------------------------------------------|
  /// | [ThaiAddressLanguage.thai]       | `กรุณาเลือกที่อยู่ให้ครบ`                              |
  /// | [ThaiAddressLanguage.english]    | `Please select a complete address`                    |
  /// | [ThaiAddressLanguage.bilingual]  | `กรุณาเลือกที่อยู่ให้ครบ (Please select a complete address)` |
  ///
  /// ```dart
  /// ThaiAddressFormField(
  ///   validator: ThaiAddressValidators.required(
  ///     language: ThaiAddressLanguage.thai,
  ///   ),
  /// )
  /// ```
  static FormFieldValidator<ThaiAddressSelection> required({
    ThaiAddressLanguage language = ThaiAddressLanguage.thai,
    String? message,
  }) {
    return (value) {
      if (value != null && value.isComplete) return null;
      return message ?? _defaultMessage(language);
    };
  }

  /// The built-in "required" error text for [language].
  static String _defaultMessage(ThaiAddressLanguage language) {
    switch (language) {
      case ThaiAddressLanguage.thai:
        return 'กรุณาเลือกที่อยู่ให้ครบ';
      case ThaiAddressLanguage.english:
        return 'Please select a complete address';
      case ThaiAddressLanguage.bilingual:
        return 'กรุณาเลือกที่อยู่ให้ครบ (Please select a complete address)';
    }
  }
}
