import 'package:flutter/material.dart';

import '../../core/api/api_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../../widgets/challingo/tilo.dart';
import 'game_catalog.dart';

class PlayOutcome {
  const PlayOutcome({required this.game, required this.status, required this.elapsedMs, required this.result});

  final GameKind game;
  final AttemptStatus status;
  final int? elapsedMs;

  /// The game's raw result or last server reply (points, guesses, moves, the answer…).
  final Map<String, dynamic>? result;

  bool get solved => status == AttemptStatus.solved;
}

/// End of an attempt. Practice rounds show the player's own result; ranked boards arrive with Stage 2.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.outcome, required this.onPlayAgain, required this.onHome});

  final PlayOutcome outcome;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = outcome.result ?? const {};
    final headline = switch (outcome.status) {
      AttemptStatus.solved => outcome.game == GameKind.wordHunt ? 'Round over. Nice hunting!' : 'Solved!',
      AttemptStatus.failed => (r['mine'] == true) ? 'Boom — a mine.' : 'So close!',
      AttemptStatus.expired => 'The round closed.',
      AttemptStatus.inProgress => '',
    };
    final reveal = switch (r) {
      {'answer': final String answer} => 'The word was ${answer.toUpperCase()}.',
      {'code': final List<dynamic> _} => 'The code is shown on the board.',
      _ => null,
    };

    final stats = <(String, String)>[
      if (outcome.elapsedMs != null) ('TIME', formatDuration(Duration(milliseconds: outcome.elapsedMs!))),
      if (r['points'] != null) ('POINTS', '${r['points']}'),
      if (r['words'] != null) ('WORDS', '${r['words']}'),
      if (r['guesses'] != null) ('GUESSES', '${r['guesses']}'),
      if (r['moves'] != null) ('MOVES', '${r['moves']}'),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                SquareIconButton(icon: Icons.close_rounded, label: 'Close', onPressed: onHome),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${outcome.game.title} results', style: text.titleLarge),
                    Text('Practice · not ranked', style: text.bodySmall),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: outcome.solved ? AppColors.violet : Colors.white, borderRadius: BorderRadius.circular(28)),
                child: Row(children: [
                  Tilo(
                    size: 96,
                    mood: outcome.solved ? TiloMood.cheering : TiloMood.thinking,
                    body: outcome.solved ? Colors.white : AppColors.violet,
                    face: outcome.solved ? AppColors.violet : Colors.white,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        headline,
                        style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 28, height: 1.05, color: outcome.solved ? Colors.white : AppColors.ink),
                      ),
                      if (reveal != null) ...[
                        const SizedBox(height: 6),
                        Text(reveal, style: TextStyle(fontWeight: FontWeight.w700, color: outcome.solved ? Colors.white : AppColors.inkMuted)),
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
              Text(
                'Ranked rounds put your time on the global, country and group boards.',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
              const Spacer(),
              PillButton(label: 'Play again', onPressed: onPlayAgain),
              const SizedBox(height: 14),
              PillButton(label: 'Back to home', onPressed: onHome, style: PillStyle.secondary),
            ],
          ),
        ),
      ),
    );
  }
}
