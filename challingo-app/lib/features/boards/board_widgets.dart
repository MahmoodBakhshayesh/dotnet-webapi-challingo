import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/competition_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../competition/competition_providers.dart';

/// 1st, 2nd, 3rd, 4th…
String ordinal(int n) {
  final teen = n % 100 >= 11 && n % 100 <= 13;
  final suffix = teen ? 'th' : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
  return '$n$suffix';
}

/// 1240 → "1,240".
String groupDigits(num value) {
  final s = value.round().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// Regional-indicator flag for a two-letter country code.
String flagOf(String? code) {
  if (code == null || code.length != 2) return '';
  return String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65));
}

/// A scope the player can pick: global, their country, or one of their groups.
typedef ScopeOption = ({BoardScope scope, String label, String? groupId});

/// Global · Country · groups, as a pill tab bar (scrolls when there are many groups).
class ScopeTabs extends StatelessWidget {
  const ScopeTabs({super.key, required this.options, required this.selected, required this.onSelected});

  final List<ScopeOption> options;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: AppColors.lineSoft, borderRadius: BorderRadius.circular(999)),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final fits = options.length <= 3;
        final tabs = [
          for (final (i, o) in options.indexed)
            _ScopeTab(label: o.label, selected: i == selected, onTap: () => onSelected(i), expand: fits),
        ];
        return fits
            ? Row(children: [for (final t in tabs) Expanded(child: t)])
            : ListView(scrollDirection: Axis.horizontal, children: tabs);
      },
    ),
  );
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({required this.label, required this.selected, required this.onTap, required this.expand});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: expand ? 6 : 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(999)),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: selected ? AppColors.ink : AppColors.inkMuted),
        ),
      ),
    ),
  );
}

const _avatarColors = [AppColors.sun, AppColors.coral, AppColors.mint, AppColors.violet, Color(0xFF2F9BD6), Color(0xFFE0629B)];

/// One row: rank, avatar, name, points. The player's own row is highlighted.
class BoardRow extends StatelessWidget {
  const BoardRow({super.key, required this.entry, this.showTime = false});

  final BoardEntry entry;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final rankColor = switch (e.rank) { 1 => AppColors.sunDeep, 2 => AppColors.inkMuted, 3 => const Color(0xFFB0683A), _ => AppColors.ink };
    final initial = e.displayName.isEmpty ? '?' : e.displayName.characters.first.toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: e.isMe ? AppColors.lilac : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: e.isMe ? Border.all(color: AppColors.violet, width: 2) : null,
      ),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: Text('${e.rank}', style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 19, color: rankColor)),
        ),
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: e.isMe ? AppColors.violet : _avatarColors[e.displayName.hashCode.abs() % _avatarColors.length], shape: BoxShape.circle),
          child: Text(initial, style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            e.isMe ? 'You' : e.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        if (e.countryCode != null) Padding(padding: const EdgeInsets.only(right: 8), child: Text(flagOf(e.countryCode), style: const TextStyle(fontSize: 16))),
        if (showTime && e.elapsedMs != null)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(formatDuration(Duration(milliseconds: e.elapsedMs!)), style: Theme.of(context).textTheme.bodySmall),
          ),
        Text(groupDigits(e.points), style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 17)),
      ]),
    );
  }
}

/// Loads and shows one board: top rows, then the player's own row when it is further down.
class BoardList extends ConsumerWidget {
  const BoardList({super.key, required this.request, this.emptyText = 'No results yet. Be the first!', this.shrinkWrap = false});

  final BoardRequest request;
  final String emptyText;

  /// Inside another scroll view (results screen).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider(request));
    return board.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: AppColors.violet))),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text(e.toString(), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          TextButton(onPressed: () => ref.invalidate(boardProvider(request)), child: const Text('Try again')),
        ]),
      ),
      data: (b) {
        final showTime = b.period == BoardPeriod.round;
        final rows = <Widget>[
          if (b.entries.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(emptyText, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium)),
          for (final e in b.entries) BoardRow(entry: e, showTime: showTime),
          if (b.me != null) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 2), child: Center(child: Text('···', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkMuted)))),
            BoardRow(entry: b.me!, showTime: showTime),
          ],
          if (b.total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${groupDigits(b.total)} ${b.total == 1 ? 'player' : 'players'}${b.isFinal ? ' · final' : ' · live'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ];
        return shrinkWrap ? Column(children: rows) : ListView(padding: const EdgeInsets.only(bottom: 24), children: rows);
      },
    );
  }
}
