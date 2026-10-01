/// Lightweight email format check for optional contact fields.
/// An empty value is considered valid — combine with a required-field
/// validator when the field is mandatory.
bool isValidEmail(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
}

String? emailValidatorMessage(String value) {
  if (isValidEmail(value)) return null;
  return 'Enter a valid email address';
}
