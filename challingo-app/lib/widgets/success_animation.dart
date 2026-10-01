import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Plays the bundled check-mark animation once. Use for confirmation moments
/// (form submitted, payment succeeded, item saved) — not as a loading indicator.
class SuccessAnimation extends StatelessWidget {
  const SuccessAnimation({super.key, this.size = 120, this.onComplete});

  final double size;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/animations/check.json',
      width: size,
      height: size,
      repeat: false,
      onLoaded: (composition) {
        if (onComplete == null) return;
        Future.delayed(composition.duration, onComplete);
      },
    );
  }
}
