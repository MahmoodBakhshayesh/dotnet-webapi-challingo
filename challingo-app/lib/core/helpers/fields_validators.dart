import 'package:unified_fields/unified_fields.dart';

import 'email_validator.dart';

/// Reusable validators for `unified_fields` inputs.
///
/// [requiredMessage] can be replaced at bootstrap (e.g. in `initPackages`)
/// to localize the default "required field" text.
class FieldsValidators {
  FieldsValidators._();

  static String requiredMessage = 'فیلد اجباری';

  static String? notEmptyString(String? txt) => (txt ?? '').trim().isEmpty ? requiredMessage : null;

  static String? notEmptyNumber(num? value) => value == null ? requiredMessage : null;

  static String? notEmptyObject<T>(T? field) => field == null ? requiredMessage : null;

  static String? notEmptyCustomizer<T>(CustomizableSinglePickerController<T>? field) {
    return (field?.fieldDisplayText ?? '').isEmpty ? requiredMessage : null;
  }

  static String? notEmptyList<T>(List<T>? value) => (value ?? const []).isEmpty ? requiredMessage : null;

  static String? email(String? txt) => emailValidatorMessage(txt ?? '');
}
