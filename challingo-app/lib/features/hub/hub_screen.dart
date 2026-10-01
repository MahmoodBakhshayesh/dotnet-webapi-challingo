import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/api_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../../widgets/challingo/tilo.dart';
import '../play/game_catalog.dart';
import '../welcome/email_code_sheet.dart';
import 'profile_sheet.dart';

/// Home: who you are, and every game to practise. Daily puzzles and ranked rounds join here in Stage 2.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).value;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.violet)));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.violet,
          onRefresh: () => ref.read(sessionProvider.notifier).reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _Header(me: me),
              const SizedBox(height: 16),
              if (me.isGuest) ...[
                ChallingoCard(
                  color: AppColors.sunSoft,
                  onTap: () => EmailCodeSheet.show(context, EmailCodePurpose.linkGuest),
                  child: const Row(children: [
                    Icon(Icons.shield_outlined, color: AppColors.ink),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Playing as a guest. Add your email to keep your progress.', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              ChallingoCard(
                color: AppColors.sun,
                child: Row(children: [
                  const Tilo(size: 70, mood: TiloMood.thinking),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('DAILY PUZZLE & RANKED ROUNDS', style: text.labelSmall?.copyWith(color: AppColors.ink)),
                      const SizedBox(height: 4),
                      const Text('Coming soon', style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 24)),
                      const Text('Warm up with practice rounds below.', style: TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ),
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
  const _Header({required this.me});

  final Me me;

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
          Text('Hi, ${me.displayName}', style: Theme.of(context).textTheme.headlineSmall),
          Text([weekday, ?me.countryCode].join(' · '), style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    ]);
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
