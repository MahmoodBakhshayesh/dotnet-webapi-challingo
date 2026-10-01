import 'package:flutter/widgets.dart';

import '../../core/api/api_models.dart';

/// What a game board gets from the play shell. Boards draw the game and report moves or a final
/// answer; the shell owns the attempt, the server clock and the end-of-game flow.
class BoardContext {
  const BoardContext({
    required this.attempt,
    required this.move,
    required this.submit,
    required this.serverNow,
    required this.notify,
  });

  final AttemptStart attempt;

  /// The public puzzle (never the solution).
  Map<String, dynamic> get puzzle => attempt.puzzle;

  /// Progress kept by the server for interactive games (when resuming).
  Map<String, dynamic>? get savedState => attempt.state;

  /// Interactive games: one move, answered by the server. Throws on network/validation errors.
  final Future<MoveResult> Function(Map<String, dynamic> move) move;

  /// Final answer. A wrong-but-complete answer comes back with [SubmitResult.message] and the attempt stays open.
  final Future<SubmitResult> Function(Map<String, dynamic> submission, {List<Object?>? moves}) submit;

  /// Server time (device clock corrected by the offset measured at start).
  final DateTime Function() serverNow;

  /// Short message to the player (wrong answer, not a word…).
  final void Function(String message) notify;

  Duration get elapsed => serverNow().difference(attempt.startedAtUtc);
}

/// Base for boards: gives access to the [BoardContext] and a busy flag for in-flight requests.
abstract class BoardState<T extends StatefulWidget> extends State<T> {
  BoardContext get board;

  bool busy = false;

  /// Runs a server call with [busy] set; errors are shown to the player.
  Future<R?> send<R>(Future<R> Function() call) async {
    if (busy) return null;
    setState(() => busy = true);
    try {
      return await call();
    } catch (e) {
      board.notify(e.toString());
      return null;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
