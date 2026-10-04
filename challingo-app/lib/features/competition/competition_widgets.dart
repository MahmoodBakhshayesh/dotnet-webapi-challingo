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
  // Started in initState: a `late final` initializer would only run on first read (in dispose), so it never ticked.
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.serverNow());
}

/// "14:30" in the phone's own time zone (the server sends UTC).
String localTime(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String gameTitle(String? key) => key == null ? 'Mystery game' : (GameKind.fromKey(key)?.title ?? key);

/// "every 30 min", "every 2 h".
String cadenceLabel(int minutes) => minutes % 60 == 0 ? 'every ${minutes ~/ 60} h' : 'every $minutes min';

/// Opens the play screen for a shared challenge. [replace] swaps out the current screen (the next Grand game).
void playChallenge(BuildContext context, RunCard card, {bool replace = false}) {
  final location = '/play/${card.gameKey}?challenge=${card.challengeId}&kind=${card.kind.index}&seq=${card.sequence}';
  replace ? context.pushReplacement(location) : context.push(location);
}

/// The label a play or results screen shows under the game title.
String challengeLabel(ChallengeKind kind, int sequence) => switch (kind) {
  ChallengeKind.practice => 'Practice · not ranked',
  ChallengeKind.daily => 'Daily puzzle',
  ChallengeKind.ranked => 'Ranked run',
  ChallengeKind.grand => 'Grand Challenge · game $sequence',
};
