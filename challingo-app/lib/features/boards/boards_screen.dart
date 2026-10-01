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
import 'board_widgets.dart';

/// Global · country · each of the player's groups.
List<ScopeOption> scopeOptions(Me? me, List<GroupInfo> groups) => [
  (scope: BoardScope.global, label: 'Global', groupId: null),
  if (me?.countryCode != null) (scope: BoardScope.country, label: me!.countryName ?? me.countryCode!, groupId: null),
  for (final g in groups) (scope: BoardScope.group, label: g.name, groupId: g.groupId),
];

/// Boards tab: today, this week, the Grand Challenge and all time, in every scope.
class BoardsScreen extends ConsumerStatefulWidget {
  const BoardsScreen({super.key, this.initialPeriod});

  final BoardPeriod? initialPeriod;

  @override
  ConsumerState<BoardsScreen> createState() => _BoardsScreenState();
}

class _BoardsScreenState extends ConsumerState<BoardsScreen> {
  static const _periods = [(BoardPeriod.day, 'Today'), (BoardPeriod.week, 'Week'), (BoardPeriod.grand, 'Grand'), (BoardPeriod.allTime, 'All time')];
  late BoardPeriod _period = widget.initialPeriod ?? BoardPeriod.day;
  int _scope = 0;

  @override
  void didUpdateWidget(BoardsScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialPeriod != null && widget.initialPeriod != old.initialPeriod) _period = widget.initialPeriod!;
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider).value;
    final groups = ref.watch(groupsProvider).value ?? const [];
    final today = ref.watch(todayProvider).value;
    final options = scopeOptions(me, groups);
    final scope = options[_scope.clamp(0, options.length - 1)];
    final key = switch (_period) {
      BoardPeriod.day => today?.utcDate,
      BoardPeriod.week || BoardPeriod.grand => today?.weekKey,
      _ => null,
    };
    final subtitle = switch (_period) {
      BoardPeriod.day => 'First ranked round of the UTC day',
      BoardPeriod.week => 'Mon–Sat first rounds + the Grand Challenge',
      BoardPeriod.grand => 'Sunday: six games, one total',
      _ => 'Every counted round so far',
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Boards', style: Theme.of(context).textTheme.headlineSmall),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final (p, label) in _periods)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                      selected: _period == p,
                      showCheckmark: false,
                      selectedColor: AppColors.violet,
                      labelStyle: TextStyle(color: _period == p ? Colors.white : AppColors.ink),
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      onSelected: (_) => setState(() => _period = p),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            ScopeTabs(options: options, selected: _scope.clamp(0, options.length - 1), onSelected: (i) => setState(() => _scope = i)),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.violet,
                onRefresh: () async => ref.invalidate(boardProvider),
                child: BoardList(
                  request: (period: _period, key: key, scope: scope.scope, groupId: scope.groupId),
                  emptyText: switch (_period) {
                    BoardPeriod.grand => 'The Grand Challenge opens on Sunday.',
                    BoardPeriod.allTime => 'No results yet. Play a ranked round to get on the board!',
                    // Day and week points are final percentiles, so they arrive when each round closes.
                    _ => 'Points land here when each ranked round closes (every 4 hours). Live ranks are on the round board.',
                  },
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// One round's (or daily puzzle's, or Grand game's) board, live until it closes.
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
    final request = (period: BoardPeriod.round, key: widget.challengeId, scope: scope.scope, groupId: scope.groupId);
    final game = ref.watch(boardProvider(request)).value?.gameKey;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              SquareIconButton(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
              const SizedBox(width: 12),
              Expanded(child: Text(game == null ? 'Round board' : '${gameTitle(game)} board', style: Theme.of(context).textTheme.titleLarge)),
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
