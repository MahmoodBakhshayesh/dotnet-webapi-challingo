import 'package:flutter/material.dart';

class AppColors {
  /// Brand primary — set at generation via Mason `primary_color` (hex without #).
  static const primaryColor = Color(0xFF27756a);

  /// Action buttons / CTAs — same as [primaryColor].
  static const actions = primaryColor;
  static const secondaryColor = Color(0xFFF2C94C);

  // Surfaces
  static const scaffoldBackgroundColor = Color(0xFFF5F7FA);
  static const scaffoldHeader = Color(0xffeaecf2);
  static const cardColor = Colors.white;
  static const appBarBackground = Color(0xFF6094E7);

  // Text
  static const textColor = Color(0xFF333333);
  static const headlineColor = Color(0xFF1A1A1A);
  static const subheadColor = Color(0xFF666666);
  static const hintColor = Color(0xFF736E6B);
  static final disabledColor = Colors.grey.shade400;

  // Borders
  static const borderColor = Color(0xFFE0E0E0);
  static const borderColor1 = Color(0xFFE9E9E9);
  static const borderColor2 = Color(0xFF6C6C6C);

  // Status
  static const errorColor = Color(0xFFB00020);
  static const green = Color.fromRGBO(106, 240, 29, 1);
  static const green2 = Color(0xff2fc488);

  // Neutrals
  static const black = Color.fromRGBO(59, 59, 59, 1);
  static const black2 = Color(0xFF0a1a3a);
}
