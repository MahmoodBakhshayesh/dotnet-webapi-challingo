import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/competition_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../boards/board_widgets.dart';
import '../boards/boards_screen.dart';
import '../competition/competition_providers.dart';
import '../competition/competition_widgets.dart';
import '../competition/monetization_providers.dart';
import '../help/how_to_play_sheet.dart';
import '../play/game_catalog.dart';
import '../plus/run_unlock.dart';

/// One game: its live run, the next one, practice at a chosen level, and its day / week / month / all-time boards.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.gameKey});

  final String gameKey;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  int _level = 1;

  String get gameKey => widget.gameKey;
  String get _prefsKey => 'practice_level_$gameKey';

  @override
  void initState() {
    super.initState();
    // The practice level is remembered per game on this phone.
    SharedPreferences.getInstance().then((p) {
      final saved = p.getInt(_prefsKey);
      if (saved != null && mounted) setState(() => _level = saved.clamp(1, 4));
    });
  }

  Future<void> _setLevel(int level) async {
    setState(() => _level = level);
    (await SharedPreferences.getInstance()).setInt(_prefsKey, level);
  }

  @override
  Widget build(BuildContext context) {
    final kind = GameKind.fromKey(gameKey);
    final lobby = ref.watch(lobbyProvider).value;
    final game = lobby?.game(gameKey);
    final serverNow = ref.read(lobbyProvider.notifier).serverNow;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(children: [
              SquareIconButton(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
              const SizedBox(width: 12),
              if (kind != null) GameGlyphTile(kind, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(gameTitle(gameKey), style: text.titleLarge),
                  if (game != null) Text('A new ranked run ${cadenceLabel(game.everyMinutes)}', style: text.bodySmall),
                ]),
              ),
              if (kind != null) SquareIconButton(icon: Icons.question_mark_rounded, label: 'How to play', onPressed: () => HowToPlaySheet.show(context, kind)),
            ]),
            const SizedBox(height: 16),
            if (lobby != null && game != null)
              TickingBuilder(
                serverNow: serverNow,
                builder: (context, now) => _RunPanel(game: game, lobby: lobby, now: now, adsAvailable: ref.watch(adRewardsAvailableProvider)),
              ),
            const SizedBox(height: 20),
            Text('PRACTICE', style: text.labelSmall),
            const SizedBox(height: 8),
            if (kind?.hasLevels ?? false) ...[
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (level, name) in gameLevels)
                  ChoiceChip(
                    label: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    selected: _level == level,
                    showCheckmark: false,
                    selectedColor: AppColors.violet,
                    labelStyle: TextStyle(color: _level == level ? Colors.white : AppColors.ink),
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    onSelected: (_) => _setLevel(level),
                  ),
              ]),
              const SizedBox(height: 10),
            ],
            PillButton(
              label: (kind?.hasLevels ?? false) ? 'Practice · ${levelName(_level)}' : 'Practice (not ranked)',
              height: 50,
              style: PillStyle.secondary,
              onPressed: () => context.push((kind?.hasLevels ?? false) ? '/play/$gameKey?level=$_level' : '/play/$gameKey'),
            ),
            if (kind != null) ...[
              const SizedBox(height: 6),
              Text(kind.tagline, textAlign: TextAlign.center, style: text.bodySmall),
            ],
            const SizedBox(height: 22),
            Text('BOARDS', style: text.labelSmall),
            const SizedBox(height: 10),
            BoardsPanel(fixedGame: gameKey, shrinkWrap: true),
          ],
        ),
      ),
    );
  }
}

class _RunPanel extends StatelessWidget {
  const _RunPanel({required this.game, required this.lobby, required this.now, required this.adsAvailable});

  final GameLobby game;
  final Lobby lobby;
  final DateTime now;
  final bool adsAvailable;

  @override
  Widget build(BuildContext context) {
    final current = game.current;
    final open = current != null && current.stateAt(now) == ChallengeState.open;
    final my = current?.my;
    final next = game.next;
    final muted = Theme.of(context).textTheme.bodySmall;

    Widget action;
    String note;
    if (open && my != null && my.finished) {
      action = PillButton(label: 'See this run\'s board', height: 52, style: PillStyle.secondary, onPressed: () => context.push('/boards/round/${current.challengeId}'));
      note = 'You played this run. The next one opens ${next == null ? 'soon' : 'in ${formatDuration(next.opensAtUtc.difference(now))}'}.';
    } else if (open && my != null) {
      action = PillButton(label: 'Resume run', height: 52, onPressed: () => playChallenge(context, current));
      note = 'Your clock is running.';
    } else if (open && lobby.hasRankedEntry) {
      action = PillButton(label: 'Join run', height: 52, onPressed: () => playChallenge(context, current));
      note = lobby.plus
          ? 'Plus: unlimited runs. Every run adds to your day, week and month.'
          : 'Uses 1 of your ${lobby.rankedAllowed! - lobby.rankedUsed} runs left today. Every run adds to your totals.';
    } else if (open) {
      action = PillButton(label: 'Get more runs', height: 52, onPressed: () => RunUnlockSheet.show(context));
      note = lobby.canWatchAd && adsAvailable ? 'Watch an ad (+1 run) or go Plus for unlimited runs.' : 'Go Plus for unlimited runs, or come back tomorrow.';
    } else {
      action = const PillButton(label: 'Waiting for the next run', height: 52, onPressed: null);
      note = 'A new run starts ${cadenceLabel(game.everyMinutes)}.';
    }

    return ChallingoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(open ? 'RUN OPEN · ${game.runsToday} PLAYED TODAY' : 'NEXT RUN', style: Theme.of(context).textTheme.labelSmall)),
          LivePill(
            label: formatDuration(open ? current.joinClosesAtUtc.difference(now) : (next?.opensAtUtc.difference(now) ?? Duration.zero)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          [
            open ? 'Join before ${localTime(current.joinClosesAtUtc)}' : 'Opens at ${next == null ? '–' : localTime(next.opensAtUtc)}',
            if (GameKind.fromKey(game.gameKey)?.hasLevels ?? false) levelName((open ? current : next)?.difficulty),
          ].where((s) => s.isNotEmpty).join(' · '),
          style: muted,
        ),
        if (game.dayPoints != null) ...[
          const SizedBox(height: 4),
          Text(
            'Today: ${groupDigits(game.dayPoints!)} pts · ${ordinal(game.dayRank ?? 0)}',
            style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.violet),
          ),
        ],
        const SizedBox(height: 12),
        action,
        const SizedBox(height: 8),
        Text(note, textAlign: TextAlign.center, style: muted),
      ]),
    );
  }
}
