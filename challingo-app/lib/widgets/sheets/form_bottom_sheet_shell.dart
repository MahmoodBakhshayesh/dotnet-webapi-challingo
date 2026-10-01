import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Visual shell for modal bottom sheets: rounded top corners plus a
/// max-height cap so forms never cover the whole screen.
class FormBottomSheetShell extends StatelessWidget {
  const FormBottomSheetShell({
    super.key,
    required this.child,
    this.maxHeightFraction = 0.6,
  });

  final Widget child;
  final double maxHeightFraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Material(
        color: AppColors.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenCap = MediaQuery.sizeOf(context).height * maxHeightFraction;
            final maxHeight = constraints.hasBoundedHeight
                ? constraints.maxHeight.clamp(0.0, screenCap)
                : screenCap;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: child,
            );
          },
        ),
      ),
    );
  }
}
