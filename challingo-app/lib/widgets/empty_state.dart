import 'package:flutter/material.dart';

/// Centered placeholder for empty lists/screens: a muted icon (defaults to
/// an inbox) above a short message.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.content, this.icon, this.foregroundColor});

  final String content;
  final IconData? icon;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? const Color(0xffC5C5C5);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 250),
        child: Column(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            Icon(icon ?? Icons.inbox_outlined, size: 64, color: color),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
