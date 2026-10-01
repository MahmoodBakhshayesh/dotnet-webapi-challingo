import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/api_models.dart';
import '../../core/api/competition_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../../widgets/challingo/tilo.dart';
import '../boards/board_widgets.dart';
import '../competition/competition_providers.dart';
import '../competition/competition_widgets.dart';
import '../lottery/lottery_widgets.dart';
import '../play/game_catalog.dart';
import '../welcome/email_code_sheet.dart';
import 'profile_sheet.dart';

/// Home: the daily draw, the Grand Challenge, and every game with its live run.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).value;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.violet)));
    final lobby = ref.watch(lobbyProvider);
    final serverNow = ref.read(lobbyProvider.notifier).serverNow;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.violet,
          onRefresh: () async {
            await ref.read(sessionProvider.notifier).reload();
            await ref.read(lobbyProvider.notifier).refresh();
            await ref.read(lotteryProvider.notifier).refresh();
            ref.invalidate(groupsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _Header(me: me, stars: lobby.value?.stars),
              const SizedBox(height: 16),
              if (me.isGuest) ...[
                ChallingoCard(
                  color: AppColors.sunSoft,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  onTap: () => EmailCodeSheet.show(context, EmailCodePurpose.linkGuest),
                  child: const Row(children: [
                    Icon(Icons.shield_outlined, color: AppColors.ink),
                    SizedBox(width: 12),
                    Expanded(child: Text('Playing as a guest. Add your email to keep your stars.', style: TextStyle(fontWeight: FontWeight.w800))),
                    Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              const LotteryCard(),
              const SizedBox(height: 16),
              ...switch (lobby) {
                AsyncData(:final value) => [
                  if (value.grand.isNotEmpty) ...[_GrandCard(lobby: value, serverNow: serverNow), const SizedBox(height: 20)],
                  Row(children: [
                    Expanded(child: Text('RANKED RUNS', style: text.labelSmall)),
                    Text(
                      value.rankedAllowed == null
                          ? 'Unlimited runs'
                          : '${(value.rankedAllowed! - value.rankedUsed).clamp(0, 99)} of ${value.rankedAllowed} free runs left today',
                      style: text.bodySmall,
                    ),
                  ]),
                  const SizedBox(height: 10),
                  for (final game in value.games) ...[
                    _GameRow(game: game, lobby: value, serverNow: serverNow),
                    const SizedBox(height: 10),
                  ],
                ],
                AsyncError(:final error) => [
                  ChallingoCard(
                    onTap: () => ref.read(lobbyProvider.notifier).refresh(),
                    child: Row(children: [
                      const Tilo(size: 56, mood: TiloMood.thinking),
                      const SizedBox(width: 12),
                      Expanded(child: Text('$error\nTap to try again.', style: const TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                  ),
                ],
                _ => [const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: AppColors.violet)))],
              },
              const SizedBox(height: 10),
              const _GroupsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.me, required this.stars});

  final Me me;
  final int? stars;

  @override
  Widget build(BuildContext context) {
    final weekday = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][DateTime.parse(me.localDate).weekday - 1];
    return Row(children: [
      Semantics(
        button: true,
        label: 'Profile',
        child: GestureDetector(
          onTap: () => ProfileSheet.show(context),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.violet, borderRadius: BorderRadius.circular(15)),
            alignment: Alignment.center,
            child: Text(me.displayName.characters.first.toUpperCase(), style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 24, color: Colors.white)),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hi, ${me.displayName}', style: Theme.of(context).textTheme.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text([weekday, ?(me.countryName ?? me.countryCode)].join(' · '), style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      if (stars != null) Semantics(label: '$stars stars', child: StatPill.stars(groupDigits(stars!))),
    ]);
  }
}

/// A game in the lobby: open run (join / resume / played) or the next one's countdown.
class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.lobby, required this.serverNow});

  final GameLobby game;
  final Lobby lobby;
  final DateTime Function() serverNow;

  @override
  Widget build(BuildContext context) {
    final kind = GameKind.fromKey(game.gameKey);
    final subtitle = [
      cadenceLabel(game.everyMinutes),
      if (game.dayPoints != null) 'today ${groupDigits(game.dayPoints!)} pts · ${ordinal(game.dayRank ?? 0)}',
    ].join(' · ');
    return ChallingoCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: () => context.push('/game/${game.gameKey}'),
      child: Row(children: [
        if (kind != null) GameGlyphTile(kind, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(gameTitle(game.gameKey), style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 18)),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        TickingBuilder(serverNow: serverNow, builder: (context, now) => _RunAction(game: game, lobby: lobby, now: now)),
      ]),
    );
  }
}

class _RunAction extends StatelessWidget {
  const _RunAction({required this.game, required this.lobby, required this.now});

  final GameLobby game;
  final Lobby lobby;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final current = game.current;
    final open = current != null && current.stateAt(now) == ChallengeState.open;
    final my = current?.my;

    if (open && my != null && my.finished) {
      return _Countdown(label: 'Played', value: game.next == null ? '' : 'next ${formatDuration(game.next!.opensAtUtc.difference(now))}');
    }
    if (open && (my != null || lobby.hasRankedEntry)) {
      return _JoinButton(
        label: my != null ? 'Resume' : 'Join',
        time: formatDuration(current.joinClosesAtUtc.difference(now)),
        onTap: () => playChallenge(context, current),
      );
    }
    if (open) return const _Countdown(label: 'Open', value: 'no free runs');
    final next = game.next;
    return _Countdown(label: 'Next run', value: next == null ? 'soon' : formatDuration(next.opensAtUtc.difference(now)));
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.label, required this.time, required this.onTap});

  final String label;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.violet,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(children: [
          Text(label, style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white)),
          Text(time, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white70, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      ),
    ),
  );
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.inkMuted, fontFeatures: [FontFeature.tabularFigures()])),
  ]);
}

class _GrandCard extends StatelessWidget {
  const _GrandCard({required this.lobby, required this.serverNow});

  final Lobby lobby;
  final DateTime Function() serverNow;

  @override
  Widget build(BuildContext context) {
    final games = [...lobby.grand]..sort((a, b) => a.sequence.compareTo(b.sequence));
    final done = games.where((g) => g.my?.finished == true).length;
    final nextGame = games.where((g) => g.my?.finished != true).firstOrNull;
    return ChallingoCard(
      color: AppColors.sun,
      onTap: () => context.go('/boards?game=grand'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('GRAND CHALLENGE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5))),
          TickingBuilder(
            serverNow: serverNow,
            builder: (context, now) {
              final first = games.first;
              final state = first.stateAt(now);
              return Text(
                switch (state) {
                  ChallengeState.open => 'ends in ${formatDuration(first.joinClosesAtUtc.difference(now))}',
                  ChallengeState.upcoming => 'starts in ${_days(first.opensAtUtc.difference(now))}',
                  ChallengeState.closed => 'finished · see results',
                },
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
              );
            },
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          lobby.isGrandDay ? 'Six games, one board' : games.first.stateAt(serverNow()) == ChallengeState.closed ? 'This week\'s results' : 'This Sunday',
          style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 26),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final g in games)
            if (GameKind.fromKey(g.gameKey) case final kind?)
              Opacity(opacity: g.my?.finished == true ? 0.45 : 1, child: GameGlyphTile(kind, size: 36, background: Colors.white)),
        ]),
        if (lobby.isGrandDay && games.first.stateAt(serverNow()) == ChallengeState.open) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('$done of ${games.length} played', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            if (nextGame != null)
              FilledButton(
                onPressed: () => playChallenge(context, nextGame),
                style: FilledButton.styleFrom(backgroundColor: AppColors.ink, minimumSize: const Size(0, 44)),
                child: Text(done == 0 ? 'Start' : 'Next game', style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 18)),
              ),
          ]),
        ],
      ]),
    );
  }

  static String _days(Duration d) => d.inDays >= 1 ? '${d.inDays}d ${d.inHours % 24}h' : formatDuration(d);
}

class _GroupsCard extends ConsumerWidget {
  const _GroupsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider).value ?? const [];
    final first = groups.firstOrNull;
    return ChallingoCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: () => first == null ? context.go('/groups') : context.push('/groups/${first.groupId}'),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.group_rounded, color: AppColors.coral),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(first?.name ?? 'Play with friends', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(
              first == null
                  ? 'Start a group and share the invite link'
                  : '${first.memberCount} ${first.memberCount == 1 ? 'member' : 'members'}${groups.length > 1 ? ' · +${groups.length - 1} more groups' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
      ]),
    );
  }
}
