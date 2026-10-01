import 'package:challingo/core/theme/app_colors.dart';
import 'package:challingo/widgets/buttons/app_back_button.dart';
import 'package:flutter/material.dart';

/// Shared feature screen app bar — title, optional back button, optional trailing actions.
class FeatureAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final Widget? leading;
  final List<Widget>? actions;

  const FeatureAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.leading,
    this.actions,
  });

  static const double barHeight = 78;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: barHeight,
      color: AppColors.primaryColor,
      alignment: Alignment.center,
      child: SafeArea(
        child: Row(
          children: [
            if (leading != null)
              leading!
            else if (showBackButton)
              const AppBackButton()
            else
              const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actions != null) ...actions!,
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
