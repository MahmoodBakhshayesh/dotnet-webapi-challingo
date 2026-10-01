import 'dart:async';

import '/widgets/buttons/app_button.dart';
import 'package:flutter/material.dart';

/// Callback that may be sync or async; async ones drive the button's
/// built-in loading state.
typedef AsyncOrSyncVoidCallback = FutureOr<void> Function();

/// Shared contract for the app button family (label, icon, colors, loading,
/// Enter activation, [PressController]); concrete looks are implemented by
/// subclasses like `AppNewButton` / `AppOutlinedButton` on top of
/// [BaseButtonState].
abstract class BaseButton extends StatefulWidget {
  final double height;
  final double? width;
  final double? fontSize;
  final double? iconSize;
  final double radius;
  final AsyncOrSyncVoidCallback? onPressed;
  final AsyncOrSyncVoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;
  final ButtonStyle? style;
  final TextStyle? textStyle;
  final FocusNode? focusNode;
  final FontWeight? fontWeight;
  final bool autofocus;
  final WidgetStatesController? statesController;
  final Widget? child;
  final String label;
  final bool showLoading;
  final bool forceLoading;
  final bool disabled;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? disabledForegroundColor;
  final Color? disabledBackgroundColor;
  final Color? textColor;
  final IconData? icon;
  final BorderSide? borderSide;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool listenEnter;
  final bool requireVisibleToActivate;
  final String? tooltip;
  final bool lockSizeWhileLoading;
  final bool iconInRight;
  final PressController? controller;

  const BaseButton({
    super.key,
    this.height = 40,
    this.fontSize = 13,
    this.iconSize = 18,
    this.radius = 5,
    this.width,
    this.padding,
    this.controller,
    this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.textStyle,
    this.textColor,
    this.focusNode,
    this.borderRadius,
    this.borderSide,
    this.autofocus = false,
    this.iconInRight = false,
    this.disabled = false,
    this.statesController,
    this.showLoading = true,
    this.child,
    this.icon,
    required this.label,
    this.foregroundColor,
    this.backgroundColor,
    this.disabledForegroundColor,
    this.disabledBackgroundColor,
    this.fontWeight,
    this.listenEnter = false,
    this.requireVisibleToActivate = true,
    this.tooltip,
    this.lockSizeWhileLoading = true,
    this.forceLoading = false,
  });
}
