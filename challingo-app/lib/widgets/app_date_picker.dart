import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:unified_fields/unified_fields.dart';

import '../core/theme/app_dimens.dart';
import 'inputs/challingo_field_decoration.dart';

/// Date field styled with the app's field decoration; opens the unified date
/// picker and reports the chosen [DateTime] via [onChanged].
///
/// Supports [min]/[max] bounds, a clear button, and a locked/read-only state.
class AppDatePicker extends StatelessWidget {
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final bool autofocus;
  final bool readOnly;
  final String? label;
  final TextEditingController? controller;
  final String? Function(String v)? validator;
  final double? fontSize;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool isPassword;
  final ValueChanged<String>? onSubmit;
  final String? placeholder;
  final Widget? prefix;
  final Widget? prefixIcon;
  final Widget? suffix;
  final Widget? suffixIcon;
  final void Function(DateTime? dt) onChanged;
  final bool showClearButton;
  final bool locked;
  final bool required;
  final double height;
  final DateTime? value;
  final DateTime? min;
  final BorderSide? border;
  final DateTime? max;
  final DatePickerEntryMode mode;
  final Color? validationColor;
  final Color? backgroundColor;
  final Color? headerBgColor;
  final Color? bodyBgColor;
  final IconData? validationIcon;
  final List<int> rowLabelRatio;
  final DateFormat? valueFormat;
  final BorderRadius? radius;

  const AppDatePicker({
    super.key,
    this.label,
    this.value,
    this.valueFormat,
    this.bodyBgColor = Colors.white,
    this.headerBgColor,
    this.rowLabelRatio = const [12, 33],
    this.controller,
    this.focusNode,
    this.maxLength,
    this.validationColor,
    this.backgroundColor,
    this.placeholder,
    this.radius = const BorderRadius.all(Radius.circular(8)),
    this.height = AppDimens.controlHeight,
    this.fontSize = 14,
    this.keyboardType,
    this.inputFormatters,
    this.onSubmit,
    this.textCapitalization = TextCapitalization.none,
    this.mode = DatePickerEntryMode.calendar,
    this.textInputAction,
    this.validationIcon,
    this.style,
    this.min,
    this.max,
    this.strutStyle,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.showClearButton = false,
    this.border = ChallingoFieldDecoration.defaultBorder,
    this.locked = false,
    this.required = false,
    this.validator,
    this.prefix,
    this.prefixIcon,
    this.suffixIcon,
    this.suffix,
    required this.onChanged,
    this.autofocus = false,
    this.isPassword = false,
    this.readOnly = true,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedDateField(
      decorationSet: ChallingoFieldDecoration.decorationSet,
      decoration: ChallingoFieldDecoration.base(
        label: label,
        placeholder: placeholder,
        rowLabelRatio: rowLabelRatio,
        height: height,
        backgroundColor: bodyBgColor ?? backgroundColor ?? Colors.white,
        headerBackgroundColor: headerBgColor,
        borderRadius: radius,
        borderSide: border,
        fieldStyle: style ?? TextStyle(color: Colors.black, height: 1, fontSize: fontSize),
        prefix: prefix,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon ?? suffix ?? const SizedBox(height: 22),
        showError: true,
        validationColor: validationColor,
        validationIcon: validationIcon,
      ),
      controller: controller,
      focusNode: focusNode,
      value: value,
      min: min,
      max: max,
      mode: mode,
      valueFormat: valueFormat,
      label: label,
      placeholder: placeholder,
      validator: validator,
      onChanged: onChanged,
      onSubmit: onSubmit,
      isRequired: required,
      locked: locked,
      showClearButton: showClearButton,
      readOnly: readOnly,
      autofocus: autofocus,
      textAlign: textAlign,
    );
  }
}

extension DateTimeFormatting on DateTime? {
  String get formatYyMmDd {
    return this == null ? '' : DateFormat('yy-MM-dd').format(this!);
  }

  String get formatYyyyMmDd {
    return this == null ? '' : DateFormat('yyyy-MM-dd').format(this!);
  }

  String get formatYyMmDdSlash {
    return this == null ? '' : DateFormat('dd,MMM yyyy').format(this!);
  }

  String get formatYyMmDdSlashTrim {
    return this == null ? '' : DateFormat('dd,MMMyyyy').format(this!);
  }
}
