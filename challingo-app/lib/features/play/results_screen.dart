import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/api_models.dart';
import '../../core/api/competition_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../../widgets/challingo/tilo.dart';
import '../boards/board_widgets.dart';
import '../boards/boards_screen.dart';
import '../competition/competition_providers.dart';
import '../competition/competition_widgets.dart';
import 'game_catalog.dart';

class PlayOutcome {
  const PlayOutcome({
    required this.game,
    required this.status,
    required this.elapsedMs,
    required this.result,
    this.standing,
    this.challengeId,
    this.kind = ChallengeKind.practice,
    this.sequence = 0,
  });

  final GameKind game;
  final AttemptStatus status;
  final int? elapsedMs;

  /// The game's raw result or last server reply (points, guesses, moves, the answer…).
  final Map<String, dynamic>? result;

  /// Live rank in a shared challenge.
  final Standing? standing;
  final String? challengeId;
  final ChallengeKind kind;
  final int sequence;

  bool get solved => status == AttemptStatus.solved;
  bool get shared => kind != ChallengeKind.practice && challengeId != null;
}

/// End of an attempt: the player's result, and for shared challenges their live rank and the round board.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, required this.outcome, required this.onPlayAgain, required this.onHome});

  final PlayOutcome outcome;

  /// Practice only: a fresh puzzle of the same game.
  final VoidCallback? onPlayAgain;
  final VoidCallback onHome;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  int _scope = 0;

  @override
  Widget build(BuildContext context) {
    final outcome = widget.outcome;
    final text = Theme.of(context).textTheme;
    final r = outcome.result ?? const {};
    final standing = outcome.standing;
    final headline = switch (outcome.status) {
      _ when standing != null && outcome.status != AttemptStatus.expired =>
        standing.players == 1 ? 'First one in!' : '${ordinal(standing.rank)} of ${groupDigits(standing.players)}!',
      AttemptStatus.solved => outcome.game == GameKind.wordHunt ? 'Round over. Nice hunting!' : 'Solved!',
      AttemptStatus.failed => (r['mine'] == true) ? 'Boom — a mine.' : 'So close!',
      AttemptStatus.expired => 'The round closed.',
      AttemptStatus.inProgress => '',
    };
    final reveal = switch (r) {
      {'answer': final String answer} => 'The word was ${answer.toUpperCase()}.',
      {'code': final List<dynamic> _} => 'The code is shown on the board.',
      _ when standing != null => 'Ranks stay live until the round closes.',
      _ => null,
    };

    final stats = <(String, String)>[
      if (standing != null) ('POINTS', '~${standing.provisionalPoints}'),
      if (outcome.elapsedMs != null) ('TIME', formatDuration(Duration(milliseconds: outcome.elapsedMs!))),
      if (r['points'] != null) ('WORDS PTS', '${r['points']}'),
      if (standing == null && r['words'] != null) ('WORDS', '${r['words']}'),
      if (r['guesses'] != null) ('GUESSES', '${r['guesses']}'),
      if (r['moves'] != null) ('MOVES', '${r['moves']}'),
    ].take(3).toList();

    final good = outcome.solved || (standing != null && standing.rank <= 3);
    final options = scopeOptions(ref.watch(sessionProvider).value, ref.watch(groupsProvider).value ?? const []);
    final scope = options[_scope.clamp(0, options.length - 1)];

    // Grand Challenge: offer the next unplayed game.
    final nextGrand = outcome.kind == ChallengeKind.grand
        ? ref.watch(todayProvider).value?.grand.where((g) => g.challengeId != outcome.challengeId && g.my?.finished != true).firstOrNull
        : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                SquareIconButton(icon: Icons.close_rounded, label: 'Close', onPressed: widget.onHome),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${outcome.game.title} results', style: text.titleLarge),
                    Text(challengeLabel(outcome.kind, outcome.sequence), style: text.bodySmall),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: good ? AppColors.violet : Colors.white, borderRadius: BorderRadius.circular(28)),
                    child: Row(children: [
                      Tilo(
                        size: 96,
                        mood: good ? TiloMood.cheering : TiloMood.thinking,
                        body: good ? Colors.white : AppColors.violet,
                        face: good ? AppColors.violet : Colors.white,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            headline,
                            style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 28, height: 1.05, color: good ? Colors.white : AppColors.ink),
                          ),
                          if (reveal != null) ...[
                            const SizedBox(height: 6),
                            Text(reveal, style: TextStyle(fontWeight: FontWeight.w700, color: good ? Colors.white : AppColors.inkMuted)),
                          ],
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  if (stats.isNotEmpty)
                    Row(
                      children: [
                        for (final (i, (label, value)) in stats.indexed) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: Column(children: [
                                Text(value, style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 26)),
                                Text(label, style: text.labelSmall),
                              ]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (outcome.shared) ...[
                    ScopeTabs(options: options, selected: _scope.clamp(0, options.length - 1), onSelected: (i) => setState(() => _scope = i)),
                    const SizedBox(height: 12),
                    BoardList(
                      shrinkWrap: true,
                      request: (period: BoardPeriod.round, key: outcome.challengeId, scope: scope.scope, groupId: scope.groupId),
                    ),
                  ] else
                    Text('Ranked rounds put your time on the global, country and group boards.', textAlign: TextAlign.center, style: text.bodySmall),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(children: [
                if (widget.onPlayAgain != null) ...[PillButton(label: 'Play again', onPressed: widget.onPlayAgain), const SizedBox(height: 14)],
                if (nextGrand != null) ...[
                  PillButton(label: 'Next game: ${gameTitle(nextGrand.gameKey)}', onPressed: () => playChallenge(context, nextGrand, replace: true)),
                  const SizedBox(height: 14),
                ],
                PillButton(label: 'Back to home', onPressed: widget.onHome, style: PillStyle.secondary),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
