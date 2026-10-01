import 'package:flutter/material.dart';

class AppColors {
  // Challingo palette (visual identity canvas): violet actions, sun rewards, coral streaks/live.
  static const violet = Color(0xFF5B47F5);
  static const violetDark = Color(0xFF3524B8);
  static const lilac = Color(0xFFEEEBFF);
  static const sun = Color(0xFFFFC233);
  static const sunSoft = Color(0xFFFFF4D6);
  static const sunDeep = Color(0xFFC98A00);
  static const coral = Color(0xFFFF6A55);
  static const coralSoft = Color(0xFFFFE6E2);
  static const ink = Color(0xFF1C1A33);
  static const inkMuted = Color(0xFF5D5F78);
  static const cloud = Color(0xFFF5F6FB);
  static const line = Color(0xFFE3E5F0);
  static const lineSoft = Color(0xFFECEDF4);
  static const mint = Color(0xFF1F9D67);
  static const berry = Color(0xFFD93A4A);

  static const primaryColor = violet;

  /// Action buttons / CTAs — same as [primaryColor].
  static const actions = primaryColor;
  static const secondaryColor = sun;

  // Surfaces
  static const scaffoldBackgroundColor = cloud;
  static const scaffoldHeader = Color(0xffeaecf2);
  static const cardColor = Colors.white;
  static const appBarBackground = Color(0xFF6094E7);

  // Text
  static const textColor = ink;
  static const headlineColor = ink;
  static const subheadColor = inkMuted;
  static const hintColor = Color(0xFF736E6B);
  static final disabledColor = Colors.grey.shade400;

  // Borders
  static const borderColor = Color(0xFFE0E0E0);
  static const borderColor1 = Color(0xFFE9E9E9);
  static const borderColor2 = Color(0xFF6C6C6C);

  // Status
  static const errorColor = berry;
  static const green = Color.fromRGBO(106, 240, 29, 1);
  static const green2 = Color(0xff2fc488);

  // Neutrals
  static const black = Color.fromRGBO(59, 59, 59, 1);
  static const black2 = Color(0xFF0a1a3a);
}
