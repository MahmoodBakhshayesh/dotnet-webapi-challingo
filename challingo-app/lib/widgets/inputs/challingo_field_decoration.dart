import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unified_fields/unified_fields.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Shared [UnifiedInputDecoration] defaults for form fields.
class ChallingoFieldDecoration {
  ChallingoFieldDecoration._();

  /// Minimum body height that fits suffix icons (32px slot + 8px padding each side).
  static const double singleLineHeight = AppDimens.controlHeight;

  static const BorderSide defaultBorder =
      BorderSide(color: AppColors.borderColor1, width: 1);

  static const BorderSide focusedBorder =
      BorderSide(color: AppColors.primaryColor, width: 1);

  static const BorderSide errorBorder =
      BorderSide(color: AppColors.errorColor, width: 1);

  /// Per-state chrome with identical height and border width so focus does not resize fields.
  static const UnifiedInputDecorationSet decorationSet = UnifiedInputDecorationSet(
    focused: UnifiedInputDecoration(
      borderSide: focusedBorder,
      height: singleLineHeight,
    ),
    error: UnifiedInputDecoration(
      borderSide: errorBorder,
      height: singleLineHeight,
    ),
    valid: UnifiedInputDecoration(
      borderSide: defaultBorder,
      height: singleLineHeight,
    ),
    locked: UnifiedInputDecoration(
      borderSide: defaultBorder,
      height: singleLineHeight,
    ),
    disabled: UnifiedInputDecoration(
      borderSide: defaultBorder,
      height: singleLineHeight,
    ),
    readOnly: UnifiedInputDecoration(
      borderSide: defaultBorder,
      height: singleLineHeight,
    ),
  );

  static UnifiedInputDecoration base({
    String? label,
    String? placeholder,
    bool labelInRow = false,
    List<int> rowLabelRatio = const [12, 33],
    double? height,
    int? maxLines = 1,
    Color? backgroundColor,
    Color? headerBackgroundColor,
    BorderRadius? borderRadius,
    BorderSide? borderSide,
    TextStyle? labelStyle,
    TextStyle? fieldStyle,
    Widget? prefix,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool showError = true,
    Color? validationColor,
    IconData? validationIcon,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final multiline = maxLines != null && maxLines > 1;
    final resolvedHeight = height ?? (multiline ? null : singleLineHeight);

    return UnifiedInputDecoration(
      label: label,
      placeholder: placeholder,
      labelMode: labelInRow
          ? UnifiedFieldLabelMode.labelInRow
          : UnifiedFieldLabelMode.labelInColumn,
      rowLabelRatio: rowLabelRatio,
      height: resolvedHeight,
      backgroundColor: backgroundColor ?? Colors.white,
      headerBackgroundColor: headerBackgroundColor,
      borderRadius: borderRadius ?? BorderRadius.circular(6),
      borderSide: borderSide ?? defaultBorder,
      labelStyle: labelStyle ??
          const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textColor,
          ),
      fieldStyle: fieldStyle ??
          const TextStyle(
            fontSize: 14,
            color: AppColors.textColor,
            fontFamily: 'Kookfa',
          ),
      placeholderStyle: const TextStyle(
        color: Color(0xffC4C4C4),
        fontFamily: 'Kookfa',
      ),
      prefix: prefix,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixHeight: singleLineHeight - 16,
      suffixWidth: 32,
      showError: showError,
      validationColor: validationColor ?? AppColors.errorColor,
      validationIcon: validationIcon,
      contentPadding: contentPadding ??
          EdgeInsets.symmetric(
            horizontal: 12,
            vertical: multiline ? 10 : 8,
          ),
    );
  }

  static Widget textField({
    Key? key,
    TextEditingController? controller,
    String? label,
    String? placeholder,
    String? Function(String)? validator,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines = 1,
    int? minLines,
    int? maxLength,
    bool isPassword = false,
    bool isRequired = false,
    bool locked = false,
    bool readOnly = false,
    bool disabled = false,
    bool mustResolveTextDirectionByInput = false,
    TextAlign textAlign = TextAlign.start,
    double? height,
    bool labelInRow = false,
    TextStyle? labelStyle,
    TextStyle? fieldStyle,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return UnifiedTextField(
      key: key,
      controller: controller,
      label: label,
      placeholder: placeholder,
      validator: validator,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      isPassword: isPassword,
      isRequired: isRequired,
      locked: locked,
      readOnly: readOnly,
      disabled: disabled,
      mustResolveTextDirectionByInput: mustResolveTextDirectionByInput,
      textAlign: textAlign,
      decoration: base(
        label: label,
        placeholder: placeholder,
        labelInRow: labelInRow,
        height: height,
        maxLines: maxLines,
        labelStyle: labelStyle,
        fieldStyle: fieldStyle,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
      decorationSet: decorationSet,
    );
  }

  static Widget singlePicker<T>({
    Key? key,
    required List<T> items,
    required String label,
    T? value,
    ValueChanged<T?>? onChanged,
    required String Function(T) valueToString,
    String? placeholder,
    bool locked = false,
    bool isRequired = false,
    bool hasSearch = true,
    TextStyle? labelStyle,
    double? height,
  }) {
    return UnifiedSinglePickerField<T>(
      key: key,
      label: label,
      placeholder: placeholder ?? label,
      items: items,
      value: value,
      onChanged: onChanged,
      valueToString: valueToString,
      searchBuilder: valueToString,
      hasSearch: hasSearch && items.length > 6,
      locked: locked,
      isRequired: isRequired,
      decoration: base(
        label: label,
        placeholder: placeholder ?? label,
        height: height,
        labelStyle: labelStyle,
      ),
      decorationSet: decorationSet,
    );
  }
}
