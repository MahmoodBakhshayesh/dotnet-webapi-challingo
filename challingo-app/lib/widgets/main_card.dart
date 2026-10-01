import 'package:flutter/material.dart';

/// Grey rounded content card with default padding/margin — the standard
/// section container on list/detail screens.
class MainCard extends StatelessWidget {
  final Widget? child;

  const MainCard({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xffF4F5F7), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: child,
    );
  }
}

/// White full-width variant of [MainCard] with a hairline border.
class MainCard2 extends StatelessWidget {
  final Widget? child;

  const MainCard2({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xffffffff),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}
