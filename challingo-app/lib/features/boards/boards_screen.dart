import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/api_models.dart';
import '../../core/api/competition_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../competition/competition_providers.dart';
import '../competition/competition_widgets.dart';
import '../play/game_catalog.dart';
import 'board_widgets.dart';

/// Global · country · each of the player's groups.
List<ScopeOption> scopeOptions(Me? me, List<GroupInfo> groups) => [
  (scope: BoardScope.global, label: 'Global', groupId: null),
  if (me?.countryCode != null) (scope: BoardScope.country, label: me!.countryName ?? me.countryCode!, groupId: null),
  for (final g in groups) (scope: BoardScope.group, label: g.name, groupId: g.groupId),
];

/// Picks a game (or the Grand Challenge), a period and a scope, and shows that board.
class BoardsPanel extends ConsumerStatefulWidget {
  const BoardsPanel({
    super.key,
    this.fixedGame,
    this.fixedGroupId,
    this.includeGrand = false,
    this.initialGame,
    this.initialPeriod,
    this.shrinkWrap = false,
  });

  /// Only this game's boards (game page).
  final String? fixedGame;

  /// Only this group's boards (group page).
  final String? fixedGroupId;

  /// Adds the Grand Challenge to the game picker (Boards tab).
  final bool includeGrand;
  final String? initialGame;
  final BoardPeriod? initialPeriod;

  /// Inside another scroll view.
  final bool shrinkWrap;

  @override
  ConsumerState<BoardsPanel> createState() => _BoardsPanelState();
}

class _BoardsPanelState extends ConsumerState<BoardsPanel> {
  static const _grand = 'grand';
  static const _periods = [(BoardPeriod.day, 'Today'), (BoardPeriod.week, 'Week'), (BoardPeriod.month, 'Month'), (BoardPeriod.allTime, 'All time')];

  late String _game = widget.fixedGame ?? widget.initialGame ?? GameKind.values.first.key;
  late BoardPeriod _period = widget.initialPeriod ?? BoardPeriod.day;
  int _scope = 0;

  @override
  void didUpdateWidget(BoardsPanel old) {
    super.didUpdateWidget(old);
    if (widget.initialGame != null && widget.initialGame != old.initialGame) _game = widget.initialGame!;
    if (widget.initialPeriod != null && widget.initialPeriod != old.initialPeriod) _period = widget.initialPeriod!;
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(lobbyProvider).value;
    final isGrand = _game == _grand;
    final options = widget.fixedGroupId != null
        ? <ScopeOption>[(scope: BoardScope.group, label: 'Group', groupId: widget.fixedGroupId)]
        : scopeOptions(ref.watch(sessionProvider).value, ref.watch(groupsProvider).value ?? const []);
    final scope = options[_scope.clamp(0, options.length - 1)];
    final period = isGrand ? BoardPeriod.grand : _period;
    final key = switch (period) {
      BoardPeriod.day => lobby?.utcDate,
      BoardPeriod.week || BoardPeriod.grand => lobby?.weekKey,
      BoardPeriod.month => lobby?.monthKey,
      _ => null,
    };
    final request = (period: period, gameKey: isGrand ? null : _game, key: key, scope: scope.scope, groupId: scope.groupId);

    final header = <Widget>[
      if (widget.fixedGame == null) ...[
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (widget.includeGrand) _GameChip(label: 'Grand', selected: isGrand, onTap: () => setState(() => _game = _grand)),
              for (final g in GameKind.values)
                _GameChip(label: g.title, game: g, selected: _game == g.key, onTap: () => setState(() => _game = g.key)),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (!isGrand) ...[
        Row(children: [
          for (final (p, label) in _periods)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                selected: _period == p,
                showCheckmark: false,
                selectedColor: AppColors.violet,
                labelStyle: TextStyle(color: _period == p ? Colors.white : AppColors.ink),
                backgroundColor: Colors.white,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _period = p),
              ),
            ),
        ]),
        const SizedBox(height: 10),
      ] else ...[
        Text('Sunday: six games, one total. Stars when the day ends.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
      ],
      if (options.length > 1) ...[
        ScopeTabs(options: options, selected: _scope.clamp(0, options.length - 1), onSelected: (i) => setState(() => _scope = i)),
        const SizedBox(height: 12),
      ],
    ];

    final list = BoardList(
      request: request,
      shrinkWrap: widget.shrinkWrap,
      emptyText: switch (period) {
        BoardPeriod.grand => 'The Grand Challenge opens on Sunday.',
        BoardPeriod.allTime => 'No results yet. Play a ranked run to get on the board!',
        _ => 'Points land here as each run closes. Live ranks are on the run board.',
      },
    );

    if (widget.shrinkWrap) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...header, list]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...header, Expanded(child: list)]);
  }
}

class _GameChip extends StatelessWidget {
  const _GameChip({required this.label, required this.selected, required this.onTap, this.game});

  final String label;
  final GameKind? game;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: selected ? AppColors.ink : Colors.white, borderRadius: BorderRadius.circular(999)),
          child: Row(children: [
            if (game != null)
              GameGlyph(game!, size: 18, color: selected ? Colors.white : AppColors.ink)
            else
              const StarIcon(size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: selected ? Colors.white : AppColors.ink)),
          ]),
        ),
      ),
    ),
  );
}

/// Boards tab.
class BoardsScreen extends StatelessWidget {
  const BoardsScreen({super.key, this.initialGame, this.initialPeriod});

  final String? initialGame;
  final BoardPeriod? initialPeriod;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Boards', style: Theme.of(context).textTheme.headlineSmall),
          Text('Every game has its own day, week, month and all-time board.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          Expanded(child: BoardsPanel(includeGrand: true, initialGame: initialGame, initialPeriod: initialPeriod)),
        ]),
      ),
    ),
  );
}

/// One run's (or Grand game's) board, live until it closes.
class RoundBoardScreen extends ConsumerStatefulWidget {
  const RoundBoardScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<RoundBoardScreen> createState() => _RoundBoardScreenState();
}

class _RoundBoardScreenState extends ConsumerState<RoundBoardScreen> {
  int _scope = 0;

  @override
  Widget build(BuildContext context) {
    final options = scopeOptions(ref.watch(sessionProvider).value, ref.watch(groupsProvider).value ?? const []);
    final scope = options[_scope.clamp(0, options.length - 1)];
    final request = (period: BoardPeriod.round, gameKey: null, key: widget.challengeId, scope: scope.scope, groupId: scope.groupId);
    final game = ref.watch(boardProvider(request)).value?.gameKey;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              SquareIconButton(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
              const SizedBox(width: 12),
              Expanded(child: Text(game == null ? 'Run board' : '${gameTitle(game)} run', style: Theme.of(context).textTheme.titleLarge)),
            ]),
            const SizedBox(height: 16),
            ScopeTabs(options: options, selected: _scope.clamp(0, options.length - 1), onSelected: (i) => setState(() => _scope = i)),
            const SizedBox(height: 12),
            Expanded(child: BoardList(request: request)),
          ]),
        ),
      ),
    );
  }
}
