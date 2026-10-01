import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Styling knobs shared by `AppTimePicker`, `AppCalendarPicker`, and their
/// modal wrappers. Every field is optional; unset fields fall back to the
/// app defaults ([AppColors] / white surfaces), so `const AppPickerTheme()`
/// is the stock look.
///
/// ```dart
/// showAppTimePickerSheet(
///   context: context,
///   theme: const AppPickerTheme(
///     primaryColor: Colors.deepPurple,
///     sheetBackgroundColor: Color(0xFF16121F),
///     confirmLabel: 'Set time',
///     controlRadius: 20,
///   ),
/// );
/// ```
class AppPickerTheme {
  const AppPickerTheme({
    this.primaryColor,
    this.onPrimaryColor,
    this.sheetBackgroundColor,
    this.headlineColor,
    this.subheadColor,
    this.borderColor,
    this.accentColor,
    this.rangeBandColor,
    this.disabledColor,
    this.controlRadius,
    this.sheetRadius,
    this.confirmLabel,
    this.cancelLabel,
    this.confirmColor,
    this.confirmTextColor,
    this.cancelColor,
    this.barrierColor,
    this.railGradientColors,
  });

  /// Selection color: filled day/hour cells, bands, knobs, sliders.
  final Color? primaryColor;

  /// Content drawn on top of [primaryColor] (defaults to white).
  final Color? onPrimaryColor;

  /// Background of the bottom sheet / dialog and cards.
  final Color? sheetBackgroundColor;

  /// Strong text: readouts, day numbers, month titles.
  final Color? headlineColor;

  /// Secondary text: weekday initials, unselected values, hints.
  final Color? subheadColor;

  /// Outlines of chips, cards, and tick marks.
  final Color? borderColor;

  /// Default event-dot color (per-day dots can still override it).
  final Color? accentColor;

  /// Fill of the in-between days of a selected range.
  final Color? rangeBandColor;

  /// Text color of disabled days/values.
  final Color? disabledColor;

  /// Corner radius of chips, cards, and strip items.
  final double? controlRadius;

  /// Corner radius of the modal sheet / dialog.
  final double? sheetRadius;

  /// Overrides the localized confirm action label.
  final String? confirmLabel;

  /// Overrides the localized cancel action label.
  final String? cancelLabel;

  /// Confirm button fill (defaults to [primaryColor]).
  final Color? confirmColor;

  /// Confirm button text color (defaults to [onPrimaryColor]).
  final Color? confirmTextColor;

  /// Cancel button text/outline color (defaults to [primaryColor]).
  final Color? cancelColor;

  /// Modal barrier color behind the sheet/dialog.
  final Color? barrierColor;

  /// Top-to-bottom gradient of the `timelineRail` day rail.
  final List<Color>? railGradientColors;

  // --- resolved values -------------------------------------------------------

  Color get primary => primaryColor ?? AppColors.primaryColor;
  Color get onPrimary => onPrimaryColor ?? Colors.white;
  Color get background => sheetBackgroundColor ?? Colors.white;
  Color get headline => headlineColor ?? AppColors.headlineColor;
  Color get subhead => subheadColor ?? AppColors.subheadColor;
  Color get border => borderColor ?? AppColors.borderColor1;
  Color get accent => accentColor ?? Colors.orange;
  Color get rangeBand => rangeBandColor ?? primary.withValues(alpha: 0.13);
  Color get disabled => disabledColor ?? subhead.withValues(alpha: 0.45);
  double get radius => controlRadius ?? 12;
  double get modalRadius => sheetRadius ?? 24;
  Color get confirmFill => confirmColor ?? primary;
  Color get confirmText => confirmTextColor ?? onPrimary;
  Color get cancelFg => cancelColor ?? primary;
  List<Color> get railGradient =>
      railGradientColors ??
      const [
        Color(0xffb8c0f0),
        Color(0xffdfe6fb),
        Color(0xffffe9c2),
        Color(0xffdfe6fb),
        Color(0xffb8c0f0),
      ];

  AppPickerTheme copyWith({
    Color? primaryColor,
    Color? onPrimaryColor,
    Color? sheetBackgroundColor,
    Color? headlineColor,
    Color? subheadColor,
    Color? borderColor,
    Color? accentColor,
    Color? rangeBandColor,
    Color? disabledColor,
    double? controlRadius,
    double? sheetRadius,
    String? confirmLabel,
    String? cancelLabel,
    Color? confirmColor,
    Color? confirmTextColor,
    Color? cancelColor,
    Color? barrierColor,
    List<Color>? railGradientColors,
  }) {
    return AppPickerTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      onPrimaryColor: onPrimaryColor ?? this.onPrimaryColor,
      sheetBackgroundColor: sheetBackgroundColor ?? this.sheetBackgroundColor,
      headlineColor: headlineColor ?? this.headlineColor,
      subheadColor: subheadColor ?? this.subheadColor,
      borderColor: borderColor ?? this.borderColor,
      accentColor: accentColor ?? this.accentColor,
      rangeBandColor: rangeBandColor ?? this.rangeBandColor,
      disabledColor: disabledColor ?? this.disabledColor,
      controlRadius: controlRadius ?? this.controlRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
      confirmLabel: confirmLabel ?? this.confirmLabel,
      cancelLabel: cancelLabel ?? this.cancelLabel,
      confirmColor: confirmColor ?? this.confirmColor,
      confirmTextColor: confirmTextColor ?? this.confirmTextColor,
      cancelColor: cancelColor ?? this.cancelColor,
      barrierColor: barrierColor ?? this.barrierColor,
      railGradientColors: railGradientColors ?? this.railGradientColors,
    );
  }
}
