import 'package:flutter/material.dart';

import '../buttons/app_button.dart';
import '../dot_button.dart';

/// End-drawer body for advanced filters: header with close button, scrollable
/// content, and Clear / Apply footer actions.
class AdminFilterDrawer extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onClear;
  final VoidCallback onApply;
  final bool scrollable;

  const AdminFilterDrawer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onClear,
    required this.onApply,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 22,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xff667085))),
                    ],
                  ),
                ),
                DotButton(icon: Icons.close, onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: scrollable
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: child,
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: child,
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    reverse: true,
                    onPressed: onClear,
                    icon: Icons.filter_alt_off_outlined,
                    label: 'Clear',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    onPressed: onApply,
                    icon: Icons.check,
                    label: 'Apply',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
