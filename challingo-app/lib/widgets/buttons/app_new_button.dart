import '/widgets/buttons/app_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Rounded filled button with fade/flat variants and a loading spinner for
/// async [onPressed]; supports programmatic pressing via [PressController].
class AppNewButton extends StatefulWidget {
  final double height;
  final double? width;
  final double? fontSize;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final WidgetStatesController? statesController;
  final Widget? child;
  final String label;
  final bool showLoading;
  final bool fade;
  final bool flat;
  final bool disabled;
  final Color? color;
  final Color? foreground;
  final IconData? icon;
  final PressController? controller;

  const AppNewButton(
      {super.key,
        this.height = 48,
        this.fontSize = 13,
        this.width = 100,
        this.onPressed,
        this.onLongPress,
        this.onHover,
        this.onFocusChange,
        this.style,
        this.foreground,
        this.controller,
        this.focusNode,
        this.autofocus = false,
        this.disabled = false,
        this.statesController,
        this.showLoading = true,
        this.child,
        this.icon,
        required this.label,
        // this.loading = false,
        this.fade = false,
        this.flat = false,
        this.color});

  @override
  State<AppNewButton> createState() => _AppNewButtonState();
}

class _AppNewButtonState extends State<AppNewButton> {
  bool _loading = false;

  _onTap() {
    if (widget.onPressed is AsyncCallback) {
      if (_loading) return;
      _loading = true;
      setState(() {});
      (widget.onPressed as AsyncCallback).call().whenComplete(() {
        _loading = false;
        setState(() {});
      });
    } else {
      widget.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.controller?.bind(_onTap);

    ThemeData theme = Theme.of(context);
    Color c = widget.color ?? theme.primaryColor;
    Color foreground = widget.foreground ?? ((widget.flat|| widget.fade) ? c : Colors.white);
    Color disableC = const Color(0xffCFD5DC);
    if(widget.onPressed == null || widget.disabled){
      c = disableC;
    }
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: ElevatedButton(
        onPressed:widget.disabled?null: _onTap,
        onLongPress: widget.onLongPress,
        onFocusChange: widget.onFocusChange,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        statesController: widget.statesController,
        onHover: widget.onHover,
        style: ButtonStyle(
          fixedSize: WidgetStatePropertyAll(Size.fromHeight(widget.height)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),side: BorderSide(
              color: foreground.withValues(alpha: 0.12)
          ))),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStatePropertyAll(c.withValues(alpha: widget.flat?0: widget.fade ? 0.3 : 1)),
          foregroundColor: WidgetStatePropertyAll(foreground),
        ),
        child: Row(
          children: [
            Expanded(
              child: IndexedStack(
                alignment: Alignment.center,
                index: _loading && widget.showLoading ? 0 : 1,
                children: [
                  SpinKitThreeBounce(
                    color:foreground,
                    size: 18,
                  ),
                  widget.child ??
                      Text(
                        widget.label,
                        style: TextStyle(fontSize: widget.fontSize,color:foreground ),
                      )
                ],
              ),
            ),
            Container(
              width: widget.height-16,
              height: widget.height-16,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: darken(c,0.075)
              ),
              child: Icon(widget.icon),
            )
          ],
        ),
      ),
    );
  }
}

Color darken(Color color, [double amount = .1]) {
  assert(amount >= 0 && amount <= 1);

  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));

  return hslDark.toColor();
}