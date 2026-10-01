import 'package:flutter/material.dart';

import 'persian_digits.dart';

// --- Numeric field text (display / parse) ---------------------------------

/// Normalizes numeric field input: trim + Persian/Arabic-Indic digits → ASCII.
String normalizeNumericFieldInput(String raw) => raw.trim().toEnglishDigits();

/// Parses a possibly incomplete decimal from a text field (`null` = invalid / still typing).
double? parseLooseDoubleFieldText(String raw) {
  final s = normalizeNumericFieldInput(raw);
  if (s.isEmpty) return 0;
  if (s == '-' || s == '+' || s == '.' || s == '-.' || s == '+.') return null;
  if (s.endsWith('.') && !s.endsWith('..')) return null;
  return double.tryParse(s);
}

/// Parses a possibly incomplete integer from a text field (`null` = invalid / still typing).
int? parseLooseIntFieldText(String raw) {
  final s = normalizeNumericFieldInput(raw);
  if (s.isEmpty) return 0;
  if (s == '-' || s == '+' || s == '.' || s == '-.' || s == '+.') return null;
  if (s.endsWith('.') && !s.endsWith('..')) return null;
  final n = num.tryParse(s);
  if (n == null) return null;
  return n.round();
}

// --- Listenable sync (e.g. hooks forms) ------------------------------------

/// Runs [action] after the current frame — use when a [TextEditingController]
/// listener may run during a child's [initState] (e.g. digit localization).
void notifyAfterFrame(VoidCallback action) {
  WidgetsBinding.instance.addPostFrameCallback((_) => action());
}

/// Updates [controller] text without firing [listener]; re-attaches [listener] after.
void assignControllerText(TextEditingController controller, VoidCallback listener, String text) {
  if (controller.text == text) return;
  controller.removeListener(listener);
  controller.text = text;
  controller.addListener(listener);
}

/// Updates [notifier] without firing [listener]; re-attaches [listener] after.
void assignNotifierValue<T>(ValueNotifier<T> notifier, VoidCallback listener, T value) {
  notifier.removeListener(listener);
  notifier.value = value;
  notifier.addListener(listener);
}
