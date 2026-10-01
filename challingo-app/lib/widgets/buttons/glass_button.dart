import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'app_button.dart' show PressController;

/// Frosted-glass icon button for use over images / hero headers.
/// Async [onPressed] callbacks automatically show a loading spinner.
class GlassButton extends StatefulWidget {
  final double size;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final WidgetStatesController? statesController;
  final Widget? child;
  final IconData icon;
  final bool showLoading;
  final Color? color;
  final Color? backgroundColor;
  final BorderSide? border;
  final double radius;
  final double? iconSize;
  final PressController? controller;

  const GlassButton({
    super.key,
    this.size = 56,
    this.radius = 16,
    this.onPressed,
    this.controller,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.child,
    this.border,
    this.iconSize,
    this.backgroundColor,
    required this.icon,
    this.showLoading = true,
    this.color,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _loading = false;

  void _onTap() {
    if (widget.onPressed is AsyncCallback) {
      if (_loading) return;
      setState(() => _loading = true);
      (widget.onPressed as AsyncCallback).call().whenComplete(() {
        if (mounted) setState(() => _loading = false);
      });
    } else {
      widget.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.controller?.bind(_onTap);
    final iconColor = widget.color ?? Colors.white;
    final iconSize = widget.iconSize ?? widget.size * 0.4;
    final background = widget.backgroundColor ?? const Color.fromRGBO(255, 255, 255, 0.1);
    return ExcludeFocus(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: ElevatedButton(
          onPressed: _onTap,
          onLongPress: widget.onLongPress,
          onFocusChange: widget.onFocusChange,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          statesController: widget.statesController,
          onHover: widget.onHover,
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.radius),
                side: widget.border ?? BorderSide.none,
              ),
            ),
            fixedSize: WidgetStatePropertyAll(Size(widget.size, widget.size)),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            shadowColor: const WidgetStatePropertyAll(Colors.transparent),
            backgroundColor: WidgetStatePropertyAll(background),
            foregroundColor: WidgetStatePropertyAll(background),
          ),
          child: _loading && widget.showLoading
              ? SpinKitCircle(color: iconColor, size: iconSize)
              : widget.child ?? Icon(widget.icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}
