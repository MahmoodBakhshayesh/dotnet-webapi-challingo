import 'package:flutter/material.dart';

/// Crossfades + slides between form sections when [sectionKey] changes
/// (wizard step, conditional field group). Wraps AnimatedSwitcher so the
/// surrounding layout doesn't hard-cut.
class AnimatedFormSection extends StatelessWidget {
  const AnimatedFormSection({
    super.key,
    required this.sectionKey,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
  });

  final Object sectionKey;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      child: KeyedSubtree(key: ValueKey(sectionKey), child: child),
    );
  }
}
