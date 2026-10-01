import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Scaffold with the app's soft background — pair with [GlassPanel] for
/// frosted-glass page chrome (extracted from the DCS desktop app).
class GlassScaffold extends StatelessWidget {
  final Widget child;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  const GlassScaffold({
    super.key,
    required this.child,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.scaffoldBackgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      body: child,
    );
  }
}

/// Blurred translucent panel. Note: [BackdropFilter] is relatively expensive —
/// avoid nesting many of these in one screen or inside scrolling lists.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double blurSigma;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.blurSigma = 18,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
            boxShadow: const [
              BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.14), blurRadius: 24, offset: Offset(0, 12)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
