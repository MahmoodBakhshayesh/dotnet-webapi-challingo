import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../authenticated_media_image.dart';
import '../buttons/app_button.dart';
import '../dot_button.dart';
import '../inputs/challingo_field_decoration.dart';

/// Column definition for [AdminListTable]. Use [width] for fixed columns and
/// [flex] for proportional ones.
class AdminListColumn {
  final String label;
  final int flex;
  final double? width;

  const AdminListColumn(this.label, {this.flex = 1, this.width});
}

/// One labeled value inside a row's expanded details area.
class AdminListDetail {
  final IconData icon;
  final String label;
  final String value;

  const AdminListDetail({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// Row model for [AdminListTable]: identity, avatar, cell values, expandable
/// detail rows, and trailing action widgets.
class AdminListRowData {
  final String id;
  final IconData icon;

  /// Optional avatar/logo url — resolved via [AuthenticatedMediaImage].
  final String? avatarUrl;

  /// When true, renders [avatarUrl] as a square logo tile instead of a circle.
  final bool squareLogo;
  final String title;
  final String subtitle;
  final List<String> cells;
  final bool active;
  final List<AdminListDetail> details;
  final VoidCallback? onManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;

  const AdminListRowData({
    required this.id,
    required this.icon,
    this.avatarUrl,
    this.squareLogo = false,
    required this.title,
    required this.subtitle,
    required this.cells,
    required this.active,
    this.details = const [],
    this.onManage,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });
}

/// A labeled dropdown filter shown in the [AdminListToolbar] (current
/// [value], available [options], change callback).
class AdminListFilterOption {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const AdminListFilterOption({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
}

/// Search + filter + add toolbar shown above an [AdminListTable].
class AdminListToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchPlaceholder;
  final List<AdminListFilterOption> filters;
  final VoidCallback onClear;
  final VoidCallback? onFilter;
  final int activeFilterCount;
  final VoidCallback? onAdd;
  final String? addLabel;

  const AdminListToolbar({
    super.key,
    required this.searchController,
    required this.searchPlaceholder,
    required this.filters,
    required this.onClear,
    this.onFilter,
    this.activeFilterCount = 0,
    this.onAdd,
    this.addLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: ChallingoFieldDecoration.textField(
              controller: searchController,
              placeholder: searchPlaceholder,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: const Icon(Icons.tune, size: 18, color: Color(0xff98a2b3)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                if (filters.isNotEmpty)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: filters.map((filter) => AdminListFilterDropdown(filter: filter)).toList()),
                    ),
                  )
                else
                  const Spacer(),
                if (onFilter != null)
                  AppButton(
                    reverse: true,
                    onPressed: onFilter,
                    icon: Icons.tune,
                    label: activeFilterCount > 0 ? 'Filters ($activeFilterCount)' : 'Filters',
                  ),
                const SizedBox(width: 8),
                AppButton(
                  reverse: true,
                  onPressed: onClear,
                  icon: Icons.filter_alt_off_outlined,
                  label: 'Clear',
                ),
              ],
            ),
          ),
          if (onAdd != null && addLabel != null) ...[
            const SizedBox(width: 12),
            AppButton(
              onPressed: onAdd,
              icon: Icons.add,
              label: addLabel!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact dropdown rendering one [AdminListFilterOption]; used in the
/// toolbar and the filter drawer.
class AdminListFilterDropdown extends StatelessWidget {
  final AdminListFilterOption filter;

  const AdminListFilterDropdown({super.key, required this.filter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 142,
        child: DropdownButtonFormField<String>(
          initialValue: filter.options.contains(filter.value) ? filter.value : filter.options.first,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: filter.label,
            isDense: true,
            filled: true,
            fillColor: const Color(0xfff7fafc),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffe6edf5)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          ),
          items: filter.options
              .map((option) => DropdownMenuItem(value: option, child: Text(option, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (value) {
            if (value != null) filter.onChanged(value);
          },
        ),
      ),
    );
  }
}

/// Expandable data table for admin CRUD list screens (desktop-oriented).
class AdminListTable extends StatelessWidget {
  final List<AdminListColumn> columns;
  final List<AdminListRowData> rows;
  final String? expandedId;
  final ValueChanged<String?> onExpandedChanged;
  final String emptyMessage;

  const AdminListTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.expandedId,
    required this.onExpandedChanged,
    this.emptyMessage = 'No items found.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffe4ebf3)),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: Column(
        children: [
          _AdminListHeader(columns: columns),
          Expanded(
            child: rows.isEmpty
                ? Center(child: Text(emptyMessage))
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final expanded = expandedId == row.id;
                      return AdminListTableRow(
                        row: row,
                        columns: columns,
                        expanded: expanded,
                        onExpandChanged: () => onExpandedChanged(expanded ? null : row.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// One expandable row of [AdminListTable]: avatar + cells + actions, with an
/// animated detail section when [expanded].
class AdminListTableRow extends StatelessWidget {
  final AdminListRowData row;
  final List<AdminListColumn> columns;
  final bool expanded;
  final VoidCallback onExpandChanged;

  const AdminListTableRow({
    super.key,
    required this.row,
    required this.columns,
    required this.expanded,
    required this.onExpandChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: expanded ? const Color(0xfff3f9ff) : Colors.white,
        border: Border(
          bottom: const BorderSide(color: Color(0xffedf2f7)),
          left: BorderSide(color: expanded ? AppColors.primaryColor : Colors.transparent, width: 1.4),
          right: BorderSide(color: expanded ? AppColors.primaryColor : Colors.transparent, width: 1.4),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onExpandChanged,
            child: SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: const Color(0xff667085)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          AdminListAvatar(
                            icon: row.icon,
                            seed: row.id,
                            imageUrl: row.avatarUrl,
                            squareLogo: row.squareLogo,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(row.subtitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.subheadColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...List.generate(columns.length, (index) {
                      final column = columns[index];
                      final value = index < row.cells.length ? row.cells[index] : '-';
                      final child = _AdminCellText(value);
                      if (column.width != null) return SizedBox(width: column.width, child: child);
                      return Expanded(flex: column.flex, child: child);
                    }),
                    SizedBox(width: 108, child: AdminListStatusChip(active: row.active)),
                    SizedBox(
                      width: 132,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (row.onManage != null)
                            AdminListActionButton(kind: AdminListActionKind.settings, onPressed: row.onManage!),
                          if (row.onManage != null && (row.onEdit != null || row.onDelete != null)) const SizedBox(width: 8),
                          if (row.onEdit != null)
                            AdminListActionButton(kind: AdminListActionKind.edit, onPressed: row.onEdit!),
                          if (row.onEdit != null && row.onDelete != null) const SizedBox(width: 8),
                          if (row.onDelete != null)
                            AdminListActionButton(kind: AdminListActionKind.delete, onPressed: row.onDelete!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _AdminListExpandedDetails(row: row),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

/// Row avatar: authenticated image when [imageUrl] is set, otherwise an icon
/// on a color derived from [seed]; [squareLogo] switches circle → rounded
/// square (for logos).
class AdminListAvatar extends StatelessWidget {
  final IconData icon;
  final String seed;
  final String? imageUrl;
  final bool squareLogo;

  const AdminListAvatar({
    super.key,
    required this.icon,
    required this.seed,
    this.imageUrl,
    this.squareLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(seed);
    if (squareLogo) {
      return AuthenticatedMediaLogo(
        url: imageUrl,
        size: 34,
        backgroundColor: Colors.white,
        border: Border.all(color: AppColors.borderColor1),
        fallback: Icon(icon, size: 17, color: color),
      );
    }
    return AuthenticatedMediaAvatar(
      url: imageUrl,
      size: 34,
      backgroundColor: Colors.white,
      border: Border.all(color: AppColors.borderColor1),
      fallback: Icon(icon, size: 17, color: color),
    );
  }
}

/// Green "active" / grey "inactive" pill for status cells.
class AdminListStatusChip extends StatelessWidget {
  final bool active;

  const AdminListStatusChip({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xffdcfce7) : const Color(0xfffff1cc),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          active ? 'Active' : 'Inactive',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: active ? const Color(0xff039855) : const Color(0xffb7791f),
          ),
        ),
      ),
    );
  }
}

/// Preset icon + color pairs for row actions (settings / edit / delete /
/// toggle) used by [AdminListActionButton].
enum AdminListActionKind {
  settings(Icons.settings_outlined, AppColors.primaryColor),
  edit(Icons.edit_outlined, Color(0xff2563eb)),
  delete(Icons.delete_outline, AppColors.errorColor),
  toggle(Icons.power_settings_new_outlined, Color(0xffd97706));

  const AdminListActionKind(this.icon, this.color);

  final IconData icon;
  final Color color;
}

/// Small tinted icon button for a row action, styled by its
/// [AdminListActionKind].
class AdminListActionButton extends StatelessWidget {
  final AdminListActionKind kind;
  final VoidCallback onPressed;

  const AdminListActionButton({super.key, required this.kind, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final accent = kind.color;
    return DotButton(
      icon: kind.icon,
      onPressed: onPressed,
      color: accent,
      size: 32,
      iconSize: 16,
      fade: true,
      backgroundColor: accent.withValues(alpha: 0.12),
      border: BorderSide(color: accent.withValues(alpha: 0.22)),
    );
  }
}

class _AdminListHeader extends StatelessWidget {
  final List<AdminListColumn> columns;

  const _AdminListHeader({required this.columns});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xfffbfcfe),
        border: Border(bottom: BorderSide(color: Color(0xffedf2f7))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 56),
          const Expanded(flex: 3, child: _AdminHeaderLabel('Name')),
          ...columns.map((column) {
            final child = _AdminHeaderLabel(column.label);
            if (column.width != null) return SizedBox(width: column.width, child: child);
            return Expanded(flex: column.flex, child: child);
          }),
          const SizedBox(width: 108, child: _AdminHeaderLabel('Status')),
          const SizedBox(width: 132, child: Center(child: _AdminHeaderLabel('Actions'))),
        ],
      ),
    );
  }
}

class _AdminListExpandedDetails extends StatelessWidget {
  final AdminListRowData row;

  const _AdminListExpandedDetails({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(92, 10, 22, 20),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xffdbeafe)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...row.details.map(
            (detail) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(detail.icon, size: 15, color: const Color(0xff667085)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(detail.label, style: const TextStyle(fontSize: 11, color: Color(0xff667085), fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          Text(detail.value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xff344054))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (row.onToggleActive != null) Switch(value: row.active, onChanged: (_) => row.onToggleActive!()),
        ],
      ),
    );
  }
}

class _AdminHeaderLabel extends StatelessWidget {
  final String label;

  const _AdminHeaderLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontSize: 12, color: Color(0xff101828), fontWeight: FontWeight.w900));
  }
}

class _AdminCellText extends StatelessWidget {
  final String value;

  const _AdminCellText(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xff475467)));
  }
}

/// Joins non-empty values with commas, or `-` when nothing remains.
String adminJoinOrDash(Iterable<String?> values) {
  final text = values.whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
  return text.isEmpty ? '-' : text;
}

Color _avatarColor(String seed) {
  const colors = [
    Color(0xff2f80ed),
    Color(0xff12b76a),
    Color(0xff9b51e0),
    Color(0xfff79009),
    Color(0xffef4444),
    Color(0xff06aed4),
  ];
  final index = seed.codeUnits.fold<int>(0, (sum, code) => sum + code) % colors.length;
  return colors[index];
}
