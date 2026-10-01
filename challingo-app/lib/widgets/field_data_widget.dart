import '/core/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';

/// Read-only label/value pair for detail screens (small label above a bold
/// value).
class FieldDataWidget extends StatelessWidget {
  final String label;
  final String? data;

  const FieldDataWidget({super.key, required this.label, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.black2)),
        Text(data ?? '', style: TextStyle(fontSize: 16, color: AppColors.black2, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
