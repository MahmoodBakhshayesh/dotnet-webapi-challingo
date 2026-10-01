import 'package:challingo/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar styling + safe area + scaffold background behind the app tree.
class AppStatusBarShell extends StatelessWidget {
  final Widget child;

  const AppStatusBarShell({super.key, required this.child});

  static const SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: AppColors.scaffoldBackgroundColor,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: SafeArea(
        child: ColoredBox(
          color: AppColors.scaffoldBackgroundColor,
          child: child,
        ),
      ),
    );
  }
}
