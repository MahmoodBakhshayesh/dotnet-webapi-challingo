import 'package:flutter/material.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/theme/app_colors.dart';

/// Shows a modal popup and returns true only when the user taps Delete.
///
/// Standard delete flow for list screens — prefer this over ad-hoc dialogs.
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String message,
  String? title,
  String? itemName,
}) async {
  final l10n = context.localizations;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title ?? l10n.delete),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (itemName != null && itemName.trim().isNotEmpty) ...[
            Text(
              itemName.trim(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(message),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.errorColor),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}
