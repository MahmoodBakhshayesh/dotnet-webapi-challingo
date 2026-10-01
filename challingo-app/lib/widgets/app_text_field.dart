import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:unified_fields/unified_fields.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import 'inputs/number_input_sheet.dart';
import 'inputs/challingo_field_decoration.dart';

final globalFormValidationMode = StateProvider<bool>((ref) => false);

/// The app's standard text field: unified decoration, validation (driven by
/// [globalFormValidationMode]), password mode, numeric bottom-sheet input,
/// and focus chaining via [nextFn]/[prevFn].
class AppTextFieldNew extends ConsumerStatefulWidget {
  final FocusNode? focusNode;
  final FocusNode? nextFn;
  final FocusNode? prevFn;
  final TextInputType? keyboardType;
  final EdgeInsetsGeometry? padding;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final TextStyle? labelStyle;
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
  final int? maxLines;
  final int? minLines;
  final int? exactLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool isPassword;
  final ValueChanged<String>? onSubmit;
  final String? placeholder;
  final Widget? prefix;
  final Widget? prefixIcon;
  final Widget? suffix;
  final Widget? suffixIcon;
  final IconData? validationIcon;
  final ValueChanged<String>? onChanged;
  final bool showClearButton;
  final bool locked;
  final bool openNumberSheet;
  final bool showLimit;
  final bool required;
  final bool disabled;
  final bool labelInRow;
  final bool showError;
  final Color? validationColor;
  final Color? backgroundColor;
  final Color? headerBgColor;
  final Color? bodyBgColor;
  final BorderRadius? radius;
  final double? height;
  final double? suffixWidth;
  final BorderSide? borderSide;
  final List<int> rowLabelRatio;

  const AppTextFieldNew({
    super.key,
    this.label,
    this.headerBgColor,
    this.bodyBgColor = Colors.white,
    this.nextFn,
    this.rowLabelRatio = const [12, 33],
    this.validationColor,
    this.backgroundColor,
    this.prevFn,
    this.exactLength,
    this.labelInRow = false,
    this.openNumberSheet = false,
    this.controller,
    this.labelStyle,
    this.focusNode,
    this.maxLength,
    this.placeholder,
    this.suffixWidth,
    this.height = AppDimens.controlHeight,
    this.fontSize = 14,
    this.keyboardType,
    this.inputFormatters,
    this.onSubmit,
    this.disabled = false,
    this.showError = true,
    this.radius = const BorderRadius.all(Radius.circular(8)),
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.style,
    this.strutStyle,
    this.textDirection,
    this.validationIcon,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.showClearButton = false,
    this.locked = false,
    this.showLimit = false,
    this.required = false,
    this.validator,
    this.prefix,
    this.borderSide,
    this.prefixIcon,
    this.suffixIcon,
    this.suffix,
    this.maxLines = 1,
    this.onChanged,
    this.padding,
    this.minLines,
    this.autofocus = false,
    this.isPassword = false,
    this.readOnly = false,
  });

  @override
  ConsumerState<AppTextFieldNew> createState() => _AppTextFieldNewState();
}

class _AppTextFieldNewState extends ConsumerState<AppTextFieldNew> {
  late final TextEditingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _openNumberSheet() async {
    FocusScope.of(context).requestFocus(FocusNode());
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => NumericInputSheet(
        label: widget.label ?? '',
        maxLength: widget.maxLength,
        onDone: (value) {
          if (value is String) {
            _controller.text = value;
            widget.onSubmit?.call(value);
            widget.onChanged?.call(value);
          }
        },
      ),
    );
  }

  String? _combinedValidator(String value) {
    ref.watch(globalFormValidationMode);
    if (widget.required && value.isEmpty) {
      return '';
    }
    return widget.validator?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final field = UnifiedTextField(
      decoration: ChallingoFieldDecoration.base(
        label: widget.label,
        placeholder: widget.placeholder,
        labelInRow: widget.labelInRow,
        rowLabelRatio: widget.rowLabelRatio,
        height: widget.height,
        maxLines: widget.maxLines,
        backgroundColor: widget.bodyBgColor ?? widget.backgroundColor ?? Colors.white,
        headerBackgroundColor: widget.headerBgColor,
        borderRadius: widget.radius,
        borderSide: widget.borderSide ?? const BorderSide(color: AppColors.borderColor1),
        labelStyle: widget.labelStyle,
        fieldStyle: widget.style ?? TextStyle(fontSize: widget.fontSize),
        prefix: widget.prefix,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon ?? widget.suffix,
        showError: widget.showError,
        validationColor: widget.validationColor,
        validationIcon: widget.validationIcon,
        contentPadding: widget.padding,
      ),
      decorationSet: ChallingoFieldDecoration.decorationSet,
      controller: _controller,
      focusNode: widget.focusNode,
      label: widget.label,
      placeholder: widget.placeholder,
      validator: _combinedValidator,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmit,
      disabled: widget.disabled,
      readOnly: widget.readOnly || widget.openNumberSheet,
      locked: widget.locked,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.maxLines == 0 ? null : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      isPassword: widget.isPassword,
      isRequired: widget.required,
      textAlign: widget.textAlign,
      showClearButton: widget.showClearButton,
      textCapitalization: widget.textCapitalization,
    );

    if (!widget.openNumberSheet) return field;

    return GestureDetector(
      onTap: widget.locked || widget.disabled ? null : _openNumberSheet,
      child: AbsorbPointer(child: field),
    );
  }
}
