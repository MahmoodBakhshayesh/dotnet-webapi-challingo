import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../extensions/theme_extension.dart';
import '../models/base/flavor_config.dart';

import 'app_colors.dart';

class AppTheme {
  static final borderRadius = BorderRadius.circular(12);
  static final dialogBorderRadius = BorderRadius.circular(12);

  /// Display face: headings, numbers, timers. Text and UI use Nunito (the theme default).
  static const display = 'Fredoka';

  static TextTheme get _textTheme => const TextTheme(
    displayLarge: TextStyle(fontFamily: display, fontWeight: FontWeight.w700, fontSize: 56, color: AppColors.ink, letterSpacing: -1),
    displayMedium: TextStyle(fontFamily: display, fontWeight: FontWeight.w700, fontSize: 40, color: AppColors.ink),
    headlineMedium: TextStyle(fontFamily: display, fontWeight: FontWeight.w700, fontSize: 30, color: AppColors.ink),
    headlineSmall: TextStyle(fontFamily: display, fontWeight: FontWeight.w600, fontSize: 22, color: AppColors.ink),
    titleLarge: TextStyle(fontFamily: display, fontWeight: FontWeight.w600, fontSize: 20, color: AppColors.ink),
    titleMedium: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
    bodyLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink),
    bodyMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.ink),
    bodySmall: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.inkMuted),
    labelSmall: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5, color: AppColors.inkMuted),
  );

  static ThemeData get theme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      primary: AppColors.violet,
      secondary: AppColors.sun,
      error: AppColors.berry,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.scaffoldBackgroundColor,
    fontFamily: 'Nunito',
    textTheme: _textTheme,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: TargetPlatform.values
          .map((e) => {e: const CupertinoPageTransitionsBuilder()})
          .fold({}, (keys, values) => {...keys, ...values}),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: dialogBorderRadius),
    ),
    appBarTheme: const AppBarThemeData(
      centerTitle: false,
      backgroundColor: AppColors.appBarBackground,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle(
        systemNavigationBarColor: AppColors.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      titleTextStyle: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(),
    ),
  ).merge(appConfig.theme);
}
