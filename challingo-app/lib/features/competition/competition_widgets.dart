import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/competition_models.dart';
import '../play/game_catalog.dart';

/// Rebuilds every second with the current server time.
class TickingBuilder extends StatefulWidget {
  const TickingBuilder({super.key, required this.serverNow, required this.builder});

  final DateTime Function() serverNow;
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<TickingBuilder> createState() => _TickingBuilderState();
}

class _TickingBuilderState extends State<TickingBuilder> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.serverNow());
}

/// "12:00 UTC".
String utcTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} UTC';

String gameTitle(String? key) => key == null ? 'Mystery game' : (GameKind.fromKey(key)?.title ?? key);

/// Opens the play screen for a shared challenge.
/// [replace] swaps out the current screen (the next Grand game from a results screen).
void playChallenge(BuildContext context, ChallengeCard card, {bool replace = false}) {
  final game = card.gameKey;
  if (game == null) return;
  final location = '/play/$game?challenge=${card.challengeId}&kind=${card.kind.index}&seq=${card.sequence}';
  replace ? context.pushReplacement(location) : context.push(location);
}

/// The label a play or results screen shows under the game title.
String challengeLabel(ChallengeKind kind, int sequence) => switch (kind) {
  ChallengeKind.practice => 'Practice · not ranked',
  ChallengeKind.daily => 'Daily puzzle',
  ChallengeKind.ranked => 'Ranked round $sequence of 6',
  ChallengeKind.grand => 'Grand Challenge · game $sequence of 6',
};
