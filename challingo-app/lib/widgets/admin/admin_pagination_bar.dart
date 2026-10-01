import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Pagination footer for [AdminListTable]-style screens: range chip, page
/// size dropdown, and first/prev/page/next/last controls.
class AdminPaginationBar extends StatelessWidget {
  final int totalItems;
  final int pageIndex;
  final int pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  const AdminPaginationBar({
    super.key,
    required this.totalItems,
    required this.pageIndex,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.pageSizeOptions = const [10, 15, 20, 25, 50, 100],
  });

  int get pageCount => totalItems == 0 ? 1 : ((totalItems + pageSize - 1) ~/ pageSize);
  int get safePageIndex => pageIndex.clamp(0, pageCount - 1);
  int get firstItem => totalItems == 0 ? 0 : safePageIndex * pageSize + 1;
  int get lastItem => math.min(totalItems, (safePageIndex + 1) * pageSize);

  @override
  Widget build(BuildContext context) {
    final canPrevious = safePageIndex > 0;
    final canNext = safePageIndex < pageCount - 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffe4ebf3)),
        boxShadow: const [BoxShadow(color: Color(0x0f000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$firstItem-$lastItem of $totalItems',
              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Text('Page ${safePageIndex + 1} / $pageCount', style: const TextStyle(color: AppColors.subheadColor, fontWeight: FontWeight.w700)),
          const Spacer(),
          const Text('Rows', style: TextStyle(color: AppColors.subheadColor, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: pageSizeOptions.contains(pageSize) ? pageSize : pageSizeOptions.first,
                borderRadius: BorderRadius.circular(14),
                items: pageSizeOptions.map((size) => DropdownMenuItem<int>(value: size, child: Text('$size'))).toList(),
                onChanged: (value) {
                  if (value != null) onPageSizeChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          _PageButton(icon: Icons.keyboard_double_arrow_left, enabled: canPrevious, onPressed: () => onPageChanged(0), tooltip: 'First page'),
          _PageButton(icon: Icons.chevron_left, enabled: canPrevious, onPressed: () => onPageChanged(safePageIndex - 1), tooltip: 'Previous page'),
          _PageIndicator(pageIndex: safePageIndex, pageCount: pageCount, onPageChanged: onPageChanged),
          _PageButton(icon: Icons.chevron_right, enabled: canNext, onPressed: () => onPageChanged(safePageIndex + 1), tooltip: 'Next page'),
          _PageButton(icon: Icons.keyboard_double_arrow_right, enabled: canNext, onPressed: () => onPageChanged(pageCount - 1), tooltip: 'Last page'),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final String tooltip;

  const _PageButton({required this.icon, required this.enabled, required this.onPressed, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: enabled ? const Color(0xfff6f8fb) : const Color(0xfff8fafc),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 18, color: enabled ? const Color(0xff344054) : const Color(0xffcbd5e1))),
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int pageIndex;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  const _PageIndicator({required this.pageIndex, required this.pageCount, required this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    final start = math.max(0, math.min(pageIndex - 1, pageCount - 3));
    final end = math.min(pageCount, start + 3);
    return Row(
      children: [
        for (var i = start; i < end; i++)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onPageChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: i == pageIndex ? 42 : 34,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == pageIndex ? AppColors.primaryColor : const Color(0xfff6f8fb),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(color: i == pageIndex ? Colors.white : const Color(0xff344054), fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Client-side page slice helper for lists paginated with [AdminPaginationBar].
List<T> adminPageItems<T>(List<T> items, int pageIndex, int pageSize) {
  if (items.isEmpty) return const [];
  final safePage = pageIndex.clamp(0, (items.length + pageSize - 1) ~/ pageSize - 1);
  final start = safePage * pageSize;
  final end = math.min(items.length, start + pageSize);
  return items.sublist(start, end);
}
