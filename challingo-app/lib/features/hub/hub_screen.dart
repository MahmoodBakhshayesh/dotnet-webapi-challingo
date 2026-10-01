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
import '../play/game_catalog.dart';
import '../welcome/email_code_sheet.dart';
import 'profile_sheet.dart';

/// Home: today's puzzle, the open ranked round (or the Grand Challenge on Sunday), the week, groups, practice.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).value;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.violet)));
    final today = ref.watch(todayProvider);
    final serverNow = ref.read(todayProvider.notifier).serverNow;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.violet,
          onRefresh: () async {
            await ref.read(sessionProvider.notifier).reload();
            await ref.read(todayProvider.notifier).refresh();
            ref.invalidate(groupsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _Header(me: me, stars: today.value?.stars),
              const SizedBox(height: 16),
              if (me.isGuest) ...[
                ChallingoCard(
                  color: AppColors.sunSoft,
                  onTap: () => EmailCodeSheet.show(context, EmailCodePurpose.linkGuest),
                  child: const Row(children: [
                    Icon(Icons.shield_outlined, color: AppColors.ink),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Playing as a guest. Add your email to keep your stars and progress.', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              ...switch (today) {
                AsyncData(:final value) => [
                  if (value.isGrandDay) _GrandCard(today: value, serverNow: serverNow) else if (value.daily != null) _DailyCard(card: value.daily!),
                  const SizedBox(height: 16),
                  if (!value.isGrandDay) ...[_RoundCard(today: value, serverNow: serverNow), const SizedBox(height: 16)],
                  _WeekCard(today: value),
                  const SizedBox(height: 16),
                ],
                AsyncError(:final error) => [
                  ChallingoCard(
                    onTap: () => ref.read(todayProvider.notifier).refresh(),
                    child: Row(children: [
                      const Tilo(size: 56, mood: TiloMood.thinking),
                      const SizedBox(width: 12),
                      Expanded(child: Text('$error\nTap to try again.', style: const TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
                _ => [const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: AppColors.violet)))],
              },
              const _GroupsCard(),
              const SizedBox(height: 24),
              Text('PRACTICE', style: text.labelSmall),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [for (final game in GameKind.values) _GameCard(game: game)],
              ),
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

/// Small dark button used inside the yellow cards.
class _InkButton extends StatelessWidget {
  const _InkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      textStyle: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 18),
    ),
    child: Text(label),
  );
}

String _result(MyAttempt my) {
  if (!my.finished) return 'In progress';
  if (my.points != null) return '${my.points} pts · ${ordinal(my.rank ?? 0)}';
  return switch (my.status) {
    AttemptStatus.solved => 'Solved in ${formatDuration(Duration(milliseconds: my.elapsedMs ?? 0))}',
    AttemptStatus.failed => 'Not solved',
    _ => 'Time ran out',
  };
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.card});

  final ChallengeCard card;

  @override
  Widget build(BuildContext context) {
    final game = GameKind.fromKey(card.gameKey ?? '');
    final my = card.my;
    return ChallingoCard(
      color: AppColors.sun,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (game != null) GameGlyphTile(game, size: 42, background: Colors.white),
          const SizedBox(width: 10),
          const Text("TODAY'S PUZZLE", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 6),
        Text(gameTitle(card.gameKey), style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 30)),
        Row(children: [
          Expanded(
            child: Text(my?.finished == true ? _result(my!) : 'Resets at your midnight', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          if (my?.finished == true)
            _InkButton(label: 'Board', onPressed: () => context.push('/boards/round/${card.challengeId}'))
          else
            _InkButton(label: my == null ? 'Play' : 'Resume', onPressed: () => playChallenge(context, card)),
        ]),
      ]),
    );
  }
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({required this.today, required this.serverNow});

  final Today today;
  final DateTime Function() serverNow;

  @override
  Widget build(BuildContext context) => TickingBuilder(
    serverNow: serverNow,
    builder: (context, now) {
      final open = today.rounds.where((r) => r.stateAt(now) == ChallengeState.open).firstOrNull;
      final next = [...today.rounds, ?today.nextRound].where((r) => r.stateAt(now) == ChallengeState.upcoming).firstOrNull;
      final muted = Theme.of(context).textTheme.bodySmall;

      if (open == null) {
        return ChallingoCard(
          child: Text(
            next == null ? 'No more ranked rounds today.' : 'Next ranked round: ${gameTitle(next.gameKey)} at ${utcTime(next.opensAtUtc)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
      }

      final game = GameKind.fromKey(open.gameKey ?? '');
      final my = open.my;
      final Widget action;
      if (my?.finished == true) {
        action = PillButton(label: 'See the board', style: PillStyle.secondary, height: 52, onPressed: () => context.push('/boards/round/${open.challengeId}'));
      } else if (my != null) {
        action = PillButton(label: 'Resume round', height: 52, onPressed: () => playChallenge(context, open));
      } else if (today.hasRankedEntry) {
        action = PillButton(label: 'Join round', height: 52, onPressed: () => playChallenge(context, open));
      } else {
        action = const PillButton(label: 'No rounds left today', height: 52, onPressed: null);
      }

      return ChallingoCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('RANKED ROUND ${open.sequence} OF 6', style: Theme.of(context).textTheme.labelSmall)),
            LivePill(label: formatDuration(open.closesAtUtc.difference(now))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            if (game != null) GameGlyphTile(game, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(gameTitle(open.gameKey), style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 21)),
                Text(
                  my?.finished == true
                      ? _result(my!)
                      : next == null
                      ? 'Last round of the day'
                      : 'Next round: ${gameTitle(next.gameKey)} at ${utcTime(next.opensAtUtc)}',
                  style: muted,
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          action,
          const SizedBox(height: 8),
          Text(
            today.rankedUsed == 0
                ? 'Your first round today counts toward the week'
                : today.hasRankedEntry
                ? '${today.rankedAllowed - today.rankedUsed} ranked ${today.rankedAllowed - today.rankedUsed == 1 ? 'round' : 'rounds'} left today'
                : 'Free round used. More rounds with ads or Plus are coming soon.',
            textAlign: TextAlign.center,
            style: muted,
          ),
        ]),
      );
    },
  );
}

class _GrandCard extends StatelessWidget {
  const _GrandCard({required this.today, required this.serverNow});

  final Today today;
  final DateTime Function() serverNow;

  @override
  Widget build(BuildContext context) {
    final games = today.grand;
    final done = games.where((g) => g.my?.finished == true).length;
    final nextGame = games.where((g) => g.my?.finished != true).firstOrNull;
    return ChallingoCard(
      color: AppColors.sun,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('GRAND CHALLENGE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5))),
          if (games.isNotEmpty)
            TickingBuilder(serverNow: serverNow, builder: (context, now) => LivePill(label: formatDuration(games.first.closesAtUtc.difference(now)))),
        ]),
        const SizedBox(height: 6),
        const Text('Six games, one board', style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 28)),
        const SizedBox(height: 10),
        Row(children: [
          for (final g in games)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Opacity(
                opacity: g.my?.finished == true ? 0.45 : 1,
                child: GameKind.fromKey(g.gameKey ?? '') == null
                    ? const SizedBox(width: 36)
                    : GameGlyphTile(GameKind.fromKey(g.gameKey!)!, size: 36, background: Colors.white),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text('$done of ${games.length} played', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          if (nextGame != null)
            _InkButton(label: done == 0 ? 'Start' : 'Next game', onPressed: () => playChallenge(context, nextGame))
          else
            _InkButton(label: 'Board', onPressed: () => context.go('/boards?period=grand')),
        ]),
      ]),
    );
  }
}

class _WeekCard extends ConsumerWidget {
  const _WeekCard({required this.today});

  final Today today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(boardProvider((period: BoardPeriod.week, key: today.weekKey, scope: BoardScope.global, groupId: null))).value;
    final mine = week == null ? null : (week.me ?? week.entries.where((e) => e.isMe).firstOrNull);
    // The featured games follow the player's local date (the daily puzzle).
    final todayIndex = DateTime.parse(today.localDate).weekday - 1;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final featured = {for (final (date, game) in today.featured) DateTime.parse(date).weekday - 1: game};

    return ChallingoCard(
      onTap: () => context.go('/boards?period=week'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text('THIS WEEK', style: Theme.of(context).textTheme.labelSmall)),
          Text(
            mine == null ? 'No points yet' : '${groupDigits(mine.points)} pts · ${ordinal(mine.rank)}',
            style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 17),
          ),
        ]),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 7; i++)
              Column(children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 6 ? AppColors.sunSoft : (i == todayIndex ? AppColors.lilac : AppColors.lineSoft),
                    border: i == todayIndex ? Border.all(color: AppColors.violet, width: 3) : null,
                  ),
                  child: i == 6
                      ? const StarIcon(size: 16)
                      : GameKind.fromKey(featured[i] ?? '') == null
                      ? null
                      : GameGlyph(GameKind.fromKey(featured[i]!)!, size: 18, color: i < todayIndex ? AppColors.inkMuted : AppColors.ink),
                ),
                const SizedBox(height: 5),
                Text(letters[i], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: i == todayIndex ? AppColors.ink : AppColors.inkMuted)),
              ]),
          ],
        ),
      ]),
    );
  }
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

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});

  final GameKind game;

  @override
  Widget build(BuildContext context) => ChallingoCard(
    padding: const EdgeInsets.all(16),
    onTap: () => context.push('/play/${game.key}'),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GameGlyphTile(game, size: 46),
      const Spacer(),
      Text(game.title, style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 19)),
      const SizedBox(height: 2),
      Text(game.tagline, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
    ]),
  );
}
