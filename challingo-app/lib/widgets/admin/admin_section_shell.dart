import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../buttons/app_button.dart';
import '../dot_button.dart';
import '../glass_panel.dart';
import 'admin_list_table.dart';

/// Glass header (back + title + refresh + optional action) above a section
/// body — for admin CRUD screens.
class AdminSectionShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onRefresh;
  final Widget? action;
  final VoidCallback? onBack;

  const AdminSectionShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onRefresh,
    this.action,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: GlassPanel(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                DotButton(
                  icon: Icons.arrow_back,
                  onPressed: onBack ?? () => context.pop(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                      Text(subtitle, style: const TextStyle(color: AppColors.subheadColor)),
                    ],
                  ),
                ),
                AppButton(
                  reverse: true,
                  onPressed: onRefresh,
                  icon: Icons.refresh,
                  label: 'Refresh',
                ),
                if (action != null) ...[
                  const SizedBox(width: 10),
                  action!,
                ],
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Card-style list item with leading icon, title/subtitle, trailing widget and
/// optional edit/delete actions — for simpler (non-table) admin lists.
class AdminPanelItemWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final IconData icon;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AdminPanelItemWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.icon = Icons.inventory_2_outlined,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor1),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.subheadColor)),
              ],
            ),
          ),
          trailing,
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(width: 10),
            if (onEdit != null) AdminListActionButton(kind: AdminListActionKind.edit, onPressed: onEdit!),
            const SizedBox(width: 8),
            if (onDelete != null) AdminListActionButton(kind: AdminListActionKind.delete, onPressed: onDelete!),
          ],
        ],
      ),
    );
  }
}
