import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Small, dependency-light UI primitives shared across screens:
/// motion (staggered entrances, pressable scale) and simple surfaces.
/// Extracted from the Brewlab app.
class AppUiKit {
  AppUiKit._();

  static const short = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);

  static const curve = Curves.easeOutCubic;

  static const defaultRadius = Radius.circular(16);
  static const cardRadius = BorderRadius.all(defaultRadius);

  static BoxShadow get softShadow => BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 18,
        offset: const Offset(0, 8),
      );
}

/// Fade + slide entrance. Set [animate] to false to render instantly
/// (e.g. when re-entering a cached page).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppUiKit.slow,
    this.offset = const Offset(0, 0.08),
    this.curve = AppUiKit.curve,
    this.animate = true,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;
  final bool animate;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final delayMs = widget.delay.inMilliseconds;
    final durationMs = widget.duration.inMilliseconds;
    final totalMs = delayMs + durationMs;
    final start = totalMs == 0 ? 0.0 : delayMs / totalMs;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
      value: widget.animate ? 0 : 1,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: widget.curve),
    );
    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start, 1, curve: widget.curve),
      ),
    );

    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant FadeSlideIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate && !widget.animate) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Per-field stagger wrapper — use inside forms/lists with an [index].
class AppFieldMotion extends StatelessWidget {
  const AppFieldMotion({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 45),
  });

  final Widget child;
  final int index;
  final Duration step;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      delay: step * index,
      duration: AppUiKit.medium,
      offset: const Offset(0, 0.045),
      child: child,
    );
  }
}

/// Column whose children enter with a staggered fade/slide.
class AppStaggeredColumn extends StatelessWidget {
  const AppStaggeredColumn({
    super.key,
    required this.children,
    this.spacing = 12,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.delayStep = const Duration(milliseconds: 45),
  });

  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final Duration delayStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: spacing,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++)
          AppFieldMotion(index: i, step: delayStep, child: children[i]),
      ],
    );
  }
}

/// Tap scale feedback for cards and tiles.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.scale = 0.97,
    this.duration = AppUiKit.short,
    this.curve = AppUiKit.curve,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double scale;
  final Duration duration;
  final Curve curve;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}

/// White card with border + soft shadow.
class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color = Colors.white,
    this.borderRadius = AppUiKit.cardRadius,
    this.border,
    this.shadows,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border ?? Border.all(color: AppColors.borderColor1, width: 0.6),
        boxShadow: shadows ?? [AppUiKit.softShadow],
      ),
      child: child,
    );
  }
}

/// Selectable pill/chip filter.
class AppPillFilter extends StatelessWidget {
  const AppPillFilter({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: AppUiKit.short,
        curve: AppUiKit.curve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primaryColor : AppColors.borderColor1,
          ),
          boxShadow: selected ? [AppUiKit.softShadow] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.subheadColor,
          ),
        ),
      ),
    );
  }
}

/// AnimatedSwitcher with a subtle fade + slide transition.
class AppAnimatedSwap extends StatelessWidget {
  const AppAnimatedSwap({
    super.key,
    required this.child,
    this.duration = AppUiKit.medium,
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppUiKit.curve,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: child,
    );
  }
}
