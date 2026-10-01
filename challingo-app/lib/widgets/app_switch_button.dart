import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Labeled Cupertino-style switch row that matches the app's form-field
/// chrome (same label column layout as the pickers/text fields).
class AppSwitchButton extends StatelessWidget {
  final bool value;
  final bool disabled;
  final void Function(bool v) onChanged;
  final String label;
  final Widget? labelWidget;
  final Color? color;
  final Color? backgroundColor;
  final double? height;
  final BorderRadius? radius;
  final EdgeInsetsGeometry? padding;
  final Color? headerBgColor;
  final Color? bodyBgColor;
  final List<int> rowLabelRatio;

  const AppSwitchButton({
    super.key,
    this.labelWidget,
    required this.value,
    required this.onChanged,
    required this.label,
    this.color,
    this.padding,
    this.radius,
    this.backgroundColor,
    this.height = 45,
    this.disabled = false,
    this.headerBgColor,
    this.bodyBgColor,
    this.rowLabelRatio = const [12, 33],
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(5),
      child: Row(
        children: [
          Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: headerBgColor),
            child: labelWidget ?? Text(label, style: TextStyle(fontSize: 14)),
          ),
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bodyBgColor),
            height: height,
            child: Row(
              children: [


                TextButton(
                  style: TextButton.styleFrom(
                    padding: padding ?? EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    backgroundColor: backgroundColor ?? Colors.transparent,
                    foregroundColor: color ?? AppColors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: disabled
                      ? null
                      : () {
                          onChanged(!value);
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        child: CupertinoSwitch(value: value, onChanged: disabled ? null : onChanged, activeTrackColor: color ?? AppColors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
