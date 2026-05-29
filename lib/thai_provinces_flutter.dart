/// Cascading Thai address picker widgets (province → district → subdistrict
/// + postcode) for Flutter.
///
/// The key differentiator: **no state-management lock-in** (no
/// provider/riverpod/bloc) and **no code generation** (no
/// freezed/json_serializable/build_runner). The package depends on exactly
/// Flutter and `thai_provinces`; selection state lives in a plain
/// `ValueNotifier` ([ThaiAddressController]).
///
/// ```dart
/// import 'package:thai_provinces_flutter/thai_provinces_flutter.dart';
///
/// // Province/District/Subdistrict are re-exported, so no second import.
/// final controller = ThaiAddressController();
///
/// ThaiAddressPicker(
///   controller: controller,
///   onChanged: (sel) => print(sel.postcode),
/// );
/// ```
library;

export 'src/autocomplete_field.dart' show ThaiAddressAutocompleteField;
export 'src/controller.dart' show ThaiAddressController;
export 'src/form_field.dart' show ThaiAddressFormField;
export 'src/language.dart' show ThaiAddressLanguage, ThaiAddressLanguageLabels;
export 'src/picker.dart' show ThaiAddressPicker;
export 'src/selection.dart' show ThaiAddressSelection;
export 'src/suggestions.dart'
    show ThaiAddressSuggestion, thaiAddressSuggestions;

// Re-export the core library so consumers get Province/District/Subdistrict
// (and the data/lookup helpers) without a second import.
export 'package:thai_provinces/thai_provinces.dart';
