
import '/core/extensions/context_extension.dart';
import '/core/theme/app_dimens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// The app's primary filled button: label + optional icon, automatic loading
/// spinner while an async [onPressed] runs, optional focus-scoped Enter
/// activation ([listenEnter]), and programmatic pressing via
/// [PressController].
class AppButton extends StatefulWidget {
  final double height;
  final double? width;
  final double? fontSize;
  final double? iconSize;
  final double radius;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final FontWeight? fontWeight;
  final bool autofocus;
  final WidgetStatesController? statesController;
  final Widget? child;
  final String label;
  final bool showLoading;
  final bool fade;
  final bool iconInRight;
  final bool disabled;
  final bool reverse;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final BorderSide? borderSide;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  /// When true, Enter/NumpadEnter will trigger the button **only if the button (or its subtree) has focus**.
  /// This avoids global conflicts with PrimaryAction/other handlers.
  final bool listenEnter;

  /// If true (default), button won't activate if it's not actually visible on screen.
  final bool requireVisibleToActivate;
  final PressController? controller;

  const AppButton({
    super.key,
    this.height = AppDimens.controlHeight,
    this.fontSize = 13,
    this.iconSize = 18,
    this.radius = 5,
    this.width,
    this.padding,
    this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
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
    this.controller,
    this.icon,
    required this.label,
    this.fade = false,
    this.reverse = false,
    this.color,
    this.fontWeight,
    this.listenEnter = false,
    this.requireVisibleToActivate = true,
  });

  @override
  State<AppButton> createState() => AppButtonState();
}

/// State of [AppButton]; exposed so callers holding a `GlobalKey` can call
/// [trigger] / [press] programmatically (e.g. submit on Enter).
class AppButtonState extends State<AppButton> {
  bool _loading = false;
  bool _pressed = false;
  final bool _isVisible = true; // updated by VisibilityDetector
  late final FocusNode _internalFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode;

  /// Programmatic trigger
  void triggerTap() => _onTap();
  void press() => _onTap();

  /// 👇 Call this from outside via the GlobalKey and `await` it
  Future<void> trigger() async {
    if (_loading) return; // avoid re-entry
    setState(() => _loading = true);
    final callback = widget.onPressed;
    if (callback == null) return;
    try {
      if (callback is AsyncCallback) {
        if (_loading) return;
        setState(() => _loading = true);
        callback().whenComplete(() {
          if (mounted) setState(() => _loading = false);
        });
      } else {
        callback();
      }
      // await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode(debugLabel: 'MyButtonFN');
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _onTap() {
    if (widget.disabled) return;
    if (widget.requireVisibleToActivate && !_isVisible) return;

    final callback = widget.onPressed;
    if (callback == null) return;

    HapticFeedback.lightImpact();

    // If the callback is async, show loading until it completes.
    if (callback is AsyncCallback) {
      if (_loading) return;
      setState(() => _loading = true);
      callback().whenComplete(() {
        if (mounted) setState(() => _loading = false);
      });
    } else {
      callback();
    }
  }

  Widget _buildCoreButton(BuildContext context) {
    final disable = widget.disabled || widget.onPressed == null;

    Color c = widget.color ?? context.mainColor;
    Color backgroundColor = (!widget.reverse) ? c : Colors.transparent;
    Color fg = (widget.reverse) ? c : Colors.white;
    Color? borderColor = widget.borderSide?.color;

    if (widget.reverse) {
      final tmp = c;
      c = fg;
      fg = tmp;
    }
    if (widget.fade) {
      backgroundColor = backgroundColor.withValues(alpha: 0.3);
    }
    fg = widget.textColor ?? fg;

    if (disable) {
      backgroundColor = const Color(0xffECECEC);
      fg = Colors.black12;
      borderColor = Colors.black12;
    }
    widget.controller?.bind(_onTap);

    final button = SizedBox(
      height: widget.height,
      width: widget.width,
      child: TextButton(

        onPressed: disable ? null : _onTap,
        onLongPress: widget.onLongPress,
        onFocusChange: widget.onFocusChange,
        autofocus: widget.autofocus,
        focusNode: _focusNode,
        statesController: widget.statesController,
        onHover: widget.onHover,
        style: widget.style ??
            ButtonStyle(
              fixedSize: WidgetStatePropertyAll(Size.fromHeight(widget.height)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(widget.radius),
                  side: (widget.borderSide ?? BorderSide.none).copyWith(color: borderColor),
                ),
              ),



              padding: WidgetStatePropertyAll(widget.padding ?? const EdgeInsets.symmetric(horizontal: 8)),
              shadowColor: const WidgetStatePropertyAll(Colors.transparent),
              backgroundColor: WidgetStateColor.resolveWith((s)=>backgroundColor),
              foregroundColor: WidgetStatePropertyAll(widget.fade ? c : Colors.transparent),
            ),
        child: IndexedStack(
          alignment: Alignment.center,
          index: _loading && widget.showLoading ? 0 : 1,
          children: [
            SpinKitThreeBounce(color: fg, size: 18),
            Padding(
              padding: const EdgeInsets.all(2.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.iconInRight || widget.icon == null
                      ? const SizedBox()
                      : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(widget.icon, color: fg, size: widget.iconSize),
                  ),
                  widget.child != null
                      ? Expanded(child: widget.child!)
                      : Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      color: fg,
                      fontWeight: widget.fontWeight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  !widget.iconInRight || widget.icon == null
                      ? const SizedBox()
                      : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(widget.icon, color: fg, size: widget.iconSize),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final scaled = Listener(
      onPointerDown: disable ? null : (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && !disable ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: button,
      ),
    );

    // Wrap with Focus+Shortcuts **only** when listenEnter is true.
    // IMPORTANT: This binding is focus-scoped — it fires ONLY when this button (or a descendant) has focus.
    if (!widget.listenEnter) {
      return scaled;
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: true,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        },
        child: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                // Only react if this button (or a child) is the focused subtree
                if (!Focus.of(context).hasFocus) return null;
                if (widget.requireVisibleToActivate && !_isVisible) return null;
                _onTap();
                return null;
              },
            ),
          },
          child: scaled,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Visibility detector to avoid accidental activations when not really visible.
    return _buildCoreButton(context);
  }
}

/// Lets an owner press a button programmatically (and await its async
/// handler) without a `GlobalKey`; shared by [AppButton], `DotButton`, and
/// the other button widgets.
class PressController {
  Function? _press;

  void bind(Function press) {
    _press = press;
  }

  Future<void> press() async{
    await _press?.call();
  }
}