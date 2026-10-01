import 'package:flutter/material.dart';
import 'package:unified_fields/unified_fields.dart';

import 'inputs/challingo_field_decoration.dart';

/// Multi-select variant of [AppFieldPicker]: tracks the selected [values]
/// list and reports every toggle through [onChange].
class AppMultiFieldPicker<T> extends StatelessWidget {
  const AppMultiFieldPicker({
    super.key,
    this.itemToString,
    this.valueToString,
    this.searchBuilder,
    this.itemToColor,
    this.itemToWidget,
    required this.items,
    this.suggestion = const [],
    this.onChange,
    required this.values,
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
    this.style,
    this.backgroundColor,
    this.headerBgColor,
    this.bodyBgColor = Colors.white,
    this.labelStyle,
    this.rowLabelRatio = const [12, 33],
    this.suffixIcon,
  });

  final String Function(T)? itemToString;
  final String Function(T)? valueToString;
  final String Function(T)? searchBuilder;
  final Color Function(T)? itemToColor;
  final Widget Function(T)? itemToWidget;
  final List<T> items;
  final List<T> suggestion;
  final ValueChanged<List<T>>? onChange;
  final List<T> values;
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
  final TextStyle? style;
  final Color? backgroundColor;
  final Color? headerBgColor;
  final Color? bodyBgColor;
  final TextStyle? labelStyle;
  final List<int> rowLabelRatio;
  final Widget? suffixIcon;

  UnifiedInputDecoration get _decoration => ChallingoFieldDecoration.base(
        label: label,
        placeholder: placeholder,
        labelInRow: labelInRow,
        rowLabelRatio: rowLabelRatio,
        backgroundColor: bodyBgColor ?? backgroundColor,
        headerBackgroundColor: headerBgColor,
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
    return UnifiedMultiPickerField<T>(
      label: label ?? '',
      placeholder: placeholder,
      decorationSet: ChallingoFieldDecoration.decorationSet,
      items: items,
      values: values,
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
