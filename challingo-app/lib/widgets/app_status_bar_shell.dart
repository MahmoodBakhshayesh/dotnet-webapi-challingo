import 'package:challingo/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar styling + scaffold background behind the app tree. Screens add their own SafeArea so
/// full-bleed backgrounds (the violet welcome screen) reach the screen edges.
class AppStatusBarShell extends StatelessWidget {
  final Widget child;

  const AppStatusBarShell({super.key, required this.child});

  static const SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: AppColors.scaffoldBackgroundColor,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: ColoredBox(
        color: AppColors.scaffoldBackgroundColor,
        child: child,
      ),
    );
  }
}
