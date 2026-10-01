import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unified_fields/unified_fields.dart';

import 'challingo_field_decoration.dart';
import 'number_input_sheet.dart';

/// Form-integrated text field (works inside `Form`/`FormState.validate`)
/// with unified decoration, password mode, numeric bottom-sheet input, and
/// focus chaining via [nextFn]/[prevFn].
class AppTextFormField extends StatefulWidget {
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
  final bool resetValueToInitialOnLocked;
  final bool openNumberSheet;
  final bool showLimit;
  final bool isRequired;
  final bool disabled;
  final bool labelInRow;
  final bool showError;
  final Color? validationColor;
  final Color? backgroundColor;
  final Color? headerBackgroundColor;
  final BorderRadius? borderRadius;
  final double? height;
  final double? suffixWidth;
  final BorderSide? borderSide;
  final List<int> rowLabelRatio;
  final String? initialValue;
  final bool mustResolveTextDirectionByInput;

  const AppTextFormField({
    super.key,
    this.label,
    this.headerBackgroundColor,
    this.nextFn,
    this.rowLabelRatio = const [12, 33],
    this.validationColor,
    this.backgroundColor = Colors.white,
    this.prevFn,
    this.labelInRow = false,
    this.openNumberSheet = false,
    this.controller,
    this.labelStyle,
    this.focusNode,
    this.maxLength,
    this.placeholder,
    this.suffixWidth,
    this.height = 48,
    this.fontSize = 14,
    this.keyboardType,
    this.inputFormatters,
    this.onSubmit,
    this.disabled = false,
    this.showError = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
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
    this.resetValueToInitialOnLocked = true,
    this.showLimit = false,
    this.isRequired = false,
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
    this.initialValue,
    this.mustResolveTextDirectionByInput = false,
  });

  @override
  State<AppTextFormField> createState() => _AppTextFormFieldState();
}

class _AppTextFormFieldState extends State<AppTextFormField> {
  late final TextEditingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant AppTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locked && !oldWidget.locked && widget.resetValueToInitialOnLocked) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _openNumberSheet() async {
    await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
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

  UnifiedInputDecoration get _decoration => ChallingoFieldDecoration.base(
        label: widget.label,
        placeholder: widget.placeholder,
        labelInRow: widget.labelInRow,
        rowLabelRatio: widget.rowLabelRatio,
        height: widget.height,
        maxLines: widget.maxLines,
        backgroundColor: widget.backgroundColor,
        headerBackgroundColor: widget.headerBackgroundColor,
        borderRadius: widget.borderRadius,
        borderSide: widget.borderSide,
        labelStyle: widget.labelStyle,
        fieldStyle: widget.style ??
            TextStyle(fontSize: widget.fontSize, fontFamily: 'Nunito'),
        prefix: widget.prefix,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon ?? widget.suffix,
        showError: widget.showError,
        validationColor: widget.validationColor,
        validationIcon: widget.validationIcon,
        contentPadding: widget.padding,
      );

  @override
  Widget build(BuildContext context) {
    final field = UnifiedTextField(
      decoration: _decoration,
      decorationSet: ChallingoFieldDecoration.decorationSet,
      controller: _controller,
      focusNode: widget.focusNode,
      label: widget.label,
      placeholder: widget.placeholder,
      validator: widget.validator,
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
      isRequired: widget.isRequired,
      textAlign: widget.textAlign,
      initialValue: widget.controller == null ? widget.initialValue : null,
      mustResolveTextDirectionByInput: widget.mustResolveTextDirectionByInput,
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
