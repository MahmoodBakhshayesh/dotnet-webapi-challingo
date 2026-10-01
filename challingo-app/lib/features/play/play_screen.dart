import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/api_models.dart';
import '../../core/api/challingo_api.dart';
import '../../core/api/competition_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../../widgets/challingo/tilo.dart';
import '../competition/competition_providers.dart';
import '../competition/competition_widgets.dart';
import 'board_context.dart';
import 'boards/boards.dart';
import 'game_catalog.dart';
import 'results_screen.dart';

/// Plays one attempt: creates a practice challenge for [game] (or opens [challengeId]), starts/resumes it,
/// hosts the game's board, and swaps to the results when the attempt ends.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, required this.game, this.challengeId, this.kind = ChallengeKind.practice, this.sequence = 0});

  final GameKind game;
  final String? challengeId;

  /// Daily, ranked or Grand when [challengeId] is a shared challenge.
  final ChallengeKind kind;
  final int sequence;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  late final ChallingoApi _api = ref.read(challingoApiProvider);
  AttemptStart? _attempt;
  Duration _clockOffset = Duration.zero;
  Object? _error;
  PlayOutcome? _outcome;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _begin() async {
    setState(() => _error = null);
    try {
      final challengeId = widget.challengeId ?? (await _api.createPractice(widget.game.key)).challengeId;
      final attempt = await _api.start(challengeId);
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        // Device clock correction: everything time-related uses server time.
        _clockOffset = attempt.serverNowUtc.difference(DateTime.now().toUtc());
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => mounted ? setState(() {}) : null);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  DateTime _serverNow() => DateTime.now().toUtc().add(_clockOffset);

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ));
  }

  Future<MoveResult> _move(Map<String, dynamic> move) async {
    final result = await _api.move(_attempt!, move);
    if (result.status != AttemptStatus.inProgress) {
      _finish(_outcomeFor(result.status, result.elapsedMs, result.response, result.standing));
    }
    return result;
  }

  Future<SubmitResult> _submit(Map<String, dynamic> submission, {List<Object?>? moves}) async {
    final result = await _api.submit(_attempt!, submission, moves: moves);
    if (result.status == AttemptStatus.inProgress) {
      _notify(result.message ?? 'Not solved yet.');
    } else {
      _finish(_outcomeFor(result.status, result.elapsedMs, result.result, result.standing));
    }
    return result;
  }

  PlayOutcome _outcomeFor(AttemptStatus status, int? elapsedMs, Map<String, dynamic>? result, Standing? standing) => PlayOutcome(
    game: widget.game,
    status: status,
    elapsedMs: elapsedMs,
    result: result,
    standing: standing,
    challengeId: widget.challengeId,
    kind: widget.kind,
    sequence: widget.sequence,
  );

  void _finish(PlayOutcome outcome) {
    // Shared challenge: the home cards and boards change.
    if (widget.kind != ChallengeKind.practice) unawaited(ref.read(todayProvider.notifier).refresh());
    _ticker?.cancel();
    // Let the board show its final move for a moment before the results.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _outcome = outcome);
    });
  }

  void _playAgain() {
    _ticker?.cancel();
    setState(() {
      _attempt = null;
      _outcome = null;
    });
    _begin();
  }

  @override
  Widget build(BuildContext context) {
    if (_outcome != null) {
      return ResultsScreen(
        outcome: _outcome!,
        onPlayAgain: widget.kind == ChallengeKind.practice ? _playAgain : null,
        onHome: () => context.go('/home'),
      );
    }
    final attempt = _attempt;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                game: widget.game,
                label: challengeLabel(widget.kind, widget.sequence),
                attempt: attempt,
                serverNow: _serverNow,
                onBack: () => context.go('/home'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _error != null
                    ? _Problem(message: _error.toString(), onRetry: _begin)
                    : attempt == null
                    ? const Center(child: CircularProgressIndicator(color: AppColors.violet))
                    : buildBoard(
                        widget.game,
                        BoardContext(attempt: attempt, move: _move, submit: _submit, serverNow: _serverNow, notify: _notify),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.game, required this.label, required this.attempt, required this.serverNow, required this.onBack});

  final GameKind game;
  final String label;
  final AttemptStart? attempt;
  final DateTime Function() serverNow;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final a = attempt;
    // Word Hunt counts down its round; every other game shows time used.
    final limit = a?.puzzle['timeLimitSeconds'] as num?;
    final elapsed = a == null ? Duration.zero : serverNow().difference(a.startedAtUtc);
    final clock = limit != null ? Duration(seconds: limit.toInt()) - elapsed : elapsed;
    return Row(
      children: [
        SquareIconButton(icon: Icons.chevron_left_rounded, label: 'Leave', onPressed: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(game.title, style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (a != null) LivePill(label: formatDuration(clock), icon: Icons.timer_outlined),
      ],
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Tilo(size: 110, mood: TiloMood.thinking),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 20),
        SizedBox(width: 200, child: PillButton(label: 'Try again', onPressed: onRetry, height: 52)),
      ],
    ),
  );
}
