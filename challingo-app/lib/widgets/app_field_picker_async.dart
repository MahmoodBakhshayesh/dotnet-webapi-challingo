import 'package:flutter/material.dart';
import 'package:unified_fields/unified_fields.dart';

import 'inputs/challingo_field_decoration.dart';

/// Single-select picker like [AppFieldPicker], but options are fetched
/// on demand through [itemLoader] (e.g. a use case call) when opened.
class AppFieldPickerAsync<T> extends StatelessWidget {
  const AppFieldPickerAsync({
    super.key,
    this.itemToString,
    this.valueToString,
    this.searchBuilder,
    this.itemToColor,
    this.itemToWidget,
    required this.itemLoader,
    this.suggestion = const [],
    this.onChange,
    this.value,
    this.label,
    this.placeholder,
    this.showClearButton = true,
    this.supportNull = true,
    this.locked = false,
    this.prefix,
    this.prefixIcon,
    this.hasSearch = true,
    this.required = false,
    this.labelInRow = false,
    this.searchAutoFocus = false,
    this.showPickerForDesktop = true,
    this.style,
    this.backgroundColor = Colors.white,
    this.headerBgColor,
    this.bodyBgColor = Colors.white,
    this.height = 48,
    this.labelStyle,
    this.rowLabelRatio = const [12, 33],
    this.suffixIcon,
    this.radius,
    this.borderSide,
  });

  final String Function(T)? itemToString;
  final String Function(T)? valueToString;
  final String Function(T)? searchBuilder;
  final Color Function(T)? itemToColor;
  final Widget Function(T)? itemToWidget;
  final Future<List<T>> Function() itemLoader;
  final List<T> suggestion;
  final ValueChanged<T?>? onChange;
  final T? value;
  final String? label;
  final String? placeholder;
  final bool showClearButton;
  final bool supportNull;
  final bool locked;
  final Widget? prefix;
  final Widget? prefixIcon;
  final bool hasSearch;
  final bool required;
  final bool labelInRow;
  final bool searchAutoFocus;
  final bool showPickerForDesktop;
  final TextStyle? style;
  final Color? backgroundColor;
  final Color? headerBgColor;
  final Color? bodyBgColor;
  final double? height;
  final TextStyle? labelStyle;
  final List<int> rowLabelRatio;
  final Widget? suffixIcon;
  final BorderRadius? radius;
  final BoxBorder? borderSide;

  UnifiedInputDecoration get _decoration => ChallingoFieldDecoration.base(
        label: label,
        placeholder: placeholder,
        labelInRow: labelInRow,
        rowLabelRatio: rowLabelRatio,
        height: height,
        backgroundColor: bodyBgColor ?? backgroundColor,
        headerBackgroundColor: headerBgColor,
        borderRadius: radius,
        borderSide: borderSide is BorderSide ? borderSide as BorderSide? : null,
        labelStyle: labelStyle,
        fieldStyle: style,
        prefix: prefix,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      );

  String _display(T item) =>
      valueToString?.call(item) ?? itemToString?.call(item) ?? item.toString();

  @override
  Widget build(BuildContext context) {
    return UnifiedAsyncPickerField<T>(
      label: label ?? '',
      placeholder: placeholder,
      decorationSet: ChallingoFieldDecoration.decorationSet,
      itemProvider: itemLoader,
      value: value,
      onChanged: onChange,
      valueToString: _display,
      searchBuilder: searchBuilder ?? itemToString ?? _display,
      itemToWidget: itemToWidget != null
          ? (item) => itemToWidget!(item)
          : itemToColor != null
              ? (item) => Text(
                    _display(item),
                    style: TextStyle(color: itemToColor!(item)),
                  )
              : null,
      suggestion: suggestion,
      hasSearch: hasSearch,
      searchAutoFocus: searchAutoFocus,
      showClearButton: showClearButton && supportNull,
      locked: locked,
      isRequired: required,
      decoration: _decoration,
    );
  }
}
