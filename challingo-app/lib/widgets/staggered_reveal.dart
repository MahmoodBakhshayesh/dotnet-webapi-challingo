import 'package:flutter/material.dart';

/// Fades + slides a list/grid item in, staggered by [index]. Wrap each item
/// built by a ListView/GridView itemBuilder — not the whole list at once.
class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({
    super.key,
    required this.index,
    required this.child,
    this.itemDelay = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
  });

  final int index;
  final Widget child;
  final Duration itemDelay;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final delay = itemDelay * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        (delay.inMilliseconds / (duration + delay).inMilliseconds).clamp(0.0, 0.9),
        1.0,
        curve: curve,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child),
      ),
      child: child,
    );
  }
}
