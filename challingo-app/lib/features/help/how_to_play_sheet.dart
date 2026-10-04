import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../play/game_catalog.dart';
import 'game_guides.dart';
import 'grid_demo.dart';

/// Animated how-to-play guide for one game: the "?" button on the game and play screens,
/// and shown once automatically before a player's first game of each kind.
class HowToPlaySheet extends StatefulWidget {
  const HowToPlaySheet({super.key, required this.game});

  final GameKind game;

  static String _seenKey(GameKind game) => 'seen_guide_${game.key}';

  static Future<void> show(BuildContext context, GameKind game) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => HowToPlaySheet(game: game),
    );
    await _markSeen(game);
  }

  /// Shows the guide if this device has never shown it for [game].
  static Future<void> showIfFirstTime(BuildContext context, GameKind game) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_seenKey(game)) ?? false) return;
    } catch (_) {
      return;
    }
    if (context.mounted) await show(context, game);
  }

  static Future<void> _markSeen(GameKind game) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_seenKey(game), true);
    } catch (_) {}
  }

  @override
  State<HowToPlaySheet> createState() => _HowToPlaySheetState();
}

class _HowToPlaySheetState extends State<HowToPlaySheet> {
  final _pages = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guide = guideFor(widget.game);
    final text = Theme.of(context).textTheme;
    // Page 0 = goal, then one page per step; scoring goes under the last step.
    final count = guide.steps.length + 1;
    final last = _page == count - 1;
    final height = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: SizedBox(
        height: (height * 0.78).clamp(480.0, 680.0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 14),
            Row(children: [
              GameGlyphTile(widget.game, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text('How to play ${widget.game.title}', style: text.titleLarge)),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _GoalPage(game: widget.game, goal: guide.goal),
                  for (final (i, step) in guide.steps.indexed)
                    _StepPage(step: step, scoring: i == guide.steps.length - 1 ? guide.scoring : null),
                ],
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: i == _page ? AppColors.violet : AppColors.line, borderRadius: BorderRadius.circular(4)),
                ),
            ]),
            const SizedBox(height: 14),
            PillButton(
              label: last ? 'Got it' : 'Next',
              onPressed: () => last
                  ? Navigator.of(context).pop()
                  : _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  const _GoalPage({required this.game, required this.goal});

  final GameKind game;
  final String goal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      GameGlyphTile(game, size: 96),
      const SizedBox(height: 24),
      Text('The goal', style: text.titleMedium?.copyWith(color: AppColors.violet)),
      const SizedBox(height: 8),
      Text(goal, textAlign: TextAlign.center, style: text.bodyLarge),
      const SizedBox(height: 16),
      Text('Swipe or tap Next to see how.', style: text.bodySmall),
    ]);
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, this.scoring});

  final GuideStep step;
  final String? scoring;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(children: [
        if (step.frames.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            decoration: BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.circular(22)),
            child: GridDemo(columns: step.columns, rows: step.rows, frames: step.frames, frameMs: step.frameMs),
          ),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 24),
        Align(alignment: Alignment.centerLeft, child: Text(step.title, style: text.titleMedium)),
        const SizedBox(height: 6),
        Text(step.body, style: text.bodyMedium),
        if (scoring != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.lilac, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.violet, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(scoring!, style: text.bodySmall?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700))),
            ]),
          ),
        ],
      ]),
    );
  }
}
