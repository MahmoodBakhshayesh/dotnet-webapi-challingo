import 'package:flutter/material.dart';
import 'package:unified_fields/unified_fields.dart';

import 'challingo_field_decoration.dart';

/// Time-of-day field styled with the app's field decoration; opens the
/// unified time picker in input mode and reports a [TimeOfDay].
class AppTimeOfDayInputField extends StatelessWidget {
  const AppTimeOfDayInputField({
    super.key,
    required this.onChanged,
    required this.initialValue,
    this.label,
    required this.isRequired,
    required this.locked,
  });

  final ValueChanged<TimeOfDay>? onChanged;
  final TimeOfDay? initialValue;
  final String? label;
  final bool isRequired;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return UnifiedTimeOfDayField(
      label: label,
      value: initialValue,
      locked: locked,
      isRequired: isRequired,
      timePickerEntryMode: TimePickerEntryMode.input,
      onChanged: onChanged == null ? null : (value) => onChanged!(value!),
      decorationSet: ChallingoFieldDecoration.decorationSet,
      decoration: ChallingoFieldDecoration.base(
        label: label,
        labelStyle: const TextStyle(
          fontSize: 11,
          color: Color(0xff111111),
          fontWeight: FontWeight.w600,
        ),
        borderSide: const BorderSide(color: Color(0xff919191)),
        fieldStyle: const TextStyle(
          color: Color(0xff40649E),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
