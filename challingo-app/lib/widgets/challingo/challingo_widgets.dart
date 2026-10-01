import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

enum PillStyle { primary, secondary, dark, light }

/// Rounded pill button with the canvas's solid bottom shadow on primary actions.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PillStyle.primary,
    this.height = 56,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillStyle style;
  final double height;
  final bool loading;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, shadow, border) = switch (style) {
      PillStyle.primary => (AppColors.violet, Colors.white, AppColors.violetDark, null),
      PillStyle.secondary => (Colors.white, AppColors.ink, null, AppColors.line),
      PillStyle.dark => (AppColors.ink, Colors.white, null, null),
      PillStyle.light => (Colors.white, AppColors.violet, const Color(0x401C1A33), null),
    };
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled || loading ? 1 : 0.5,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: shadow == null || !enabled ? null : [BoxShadow(color: shadow, offset: const Offset(0, 5))],
        ),
        child: Material(
          color: bg,
          shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border, width: 2)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[icon!, const SizedBox(width: 8)],
                        Text(
                          label,
                          style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: height >= 56 ? 20 : 17, color: fg),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White rounded surface used for every card on the cloud background.
class ChallingoCard extends StatelessWidget {
  const ChallingoCard({super.key, required this.child, this.color = Colors.white, this.padding = const EdgeInsets.all(20), this.onTap});

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(26),
    child: InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Small rounded counter: stars, streak days, points.
class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.icon, required this.label, required this.background});

  const StatPill.stars(String label, {Key? key}) : this(key: key, icon: const StarIcon(size: 17), label: label, background: AppColors.sunSoft);

  const StatPill.streak(String label, {Key? key})
    : this(key: key, icon: const Icon(Icons.local_fire_department_rounded, size: 18, color: AppColors.coral), label: label, background: AppColors.coralSoft);

  final Widget icon;
  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: 11),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [icon, const SizedBox(width: 4), Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink))],
    ),
  );
}

/// Dark "live" pill with a coral dot: running countdowns and timers.
class LivePill extends StatelessWidget {
  const LivePill({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 18, color: Colors.white)
        else
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 19, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ],
    ),
  );
}

class StarIcon extends StatelessWidget {
  const StarIcon({super.key, this.size = 18, this.fill = AppColors.sun});

  final double size;
  final Color fill;

  @override
  // No icon shadow: Impeller can paint a text shadow far from its glyph (a stray star on screen).
  Widget build(BuildContext context) => Icon(Icons.star_rounded, size: size + 2, color: fill);
}

/// Square "back / close" button used on game and result screens.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: SizedBox.square(dimension: 44, child: Icon(icon, size: 22, color: AppColors.ink, semanticLabel: label)),
    ),
  );
}

/// Formats milliseconds as m:ss (or h:mm:ss for long countdowns).
String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
