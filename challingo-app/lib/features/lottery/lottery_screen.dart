import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/competition_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../../widgets/challingo/tilo.dart';
import '../boards/board_widgets.dart';
import '../competition/competition_providers.dart';
import '../competition/competition_widgets.dart';
import 'lottery_widgets.dart';

/// The daily draw: pick a number, watch digits drop hourly, see results and past draws.
class LotteryScreen extends ConsumerStatefulWidget {
  const LotteryScreen({super.key});

  @override
  ConsumerState<LotteryScreen> createState() => _LotteryScreenState();
}

class _LotteryScreenState extends ConsumerState<LotteryScreen> {
  String _entry = '';
  bool _editing = false;
  bool _saving = false;

  Future<void> _save(String? number) async {
    setState(() => _saving = true);
    try {
      await ref.read(lotteryProvider.notifier).pick(number);
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _key(String digit) {
    HapticFeedback.selectionClick();
    setState(() {
      if (digit == '<') {
        if (_entry.isNotEmpty) _entry = _entry.substring(0, _entry.length - 1);
      } else if (_entry.length < Lottery.digits) {
        _entry += digit;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lottery = ref.watch(lotteryProvider);
    final serverNow = ref.read(lobbyProvider.notifier).serverNow;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: switch (lottery) {
          AsyncData(value: final l?) => RefreshIndicator(
            color: AppColors.violet,
            onRefresh: () => ref.read(lotteryProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(children: [
                  SquareIconButton(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Daily draw', style: text.titleLarge),
                      Text('Draw ${l.dayKey}', style: text.bodySmall),
                    ]),
                  ),
                  StatPill.stars(groupDigits(l.pot)),
                ]),
                const SizedBox(height: 16),
                _DrawPanel(lottery: l, serverNow: serverNow),
                const SizedBox(height: 16),
                if (l.phase == LotteryPhase.picking && (l.my == null || _editing))
                  _picker(l)
                else if (l.my != null)
                  _myTicket(l)
                else
                  ChallingoCard(
                    child: Row(children: [
                      const Tilo(size: 56, mood: TiloMood.thinking),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Picks closed at ${localTime(l.picksCloseAtUtc)}. A new draw opens at ${localTime(l.endsAtUtc)}.', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                const SizedBox(height: 16),
                if (l.result != null) ...[_ResultCard(lottery: l), const SizedBox(height: 16)],
                _HowItWorks(lottery: l),
                const SizedBox(height: 16),
                _Fairness(lottery: l),
                const SizedBox(height: 20),
                Text('PAST DRAWS', style: text.labelSmall),
                const SizedBox(height: 8),
                const _History(),
              ],
            ),
          ),
          AsyncData() => const Center(child: Text('The draw is being prepared. Check back in a minute.')),
          AsyncError(:final error) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$error', textAlign: TextAlign.center))),
          _ => const Center(child: CircularProgressIndicator(color: AppColors.violet)),
        },
      ),
    );
  }

  Widget _picker(Lottery l) {
    final complete = _entry.length == Lottery.digits;
    return ChallingoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.my == null ? 'PICK YOUR NUMBER' : 'CHANGE YOUR NUMBER', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = ((constraints.maxWidth - 9 * 5) / 10).clamp(18.0, 34.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < Lottery.digits; i++)
                  DigitTile(
                    digit: i < _entry.length ? _entry[i] : null,
                    look: i < _entry.length ? DigitLook.entered : DigitLook.empty,
                    size: size,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.9,
          children: [
            for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '<'])
              Material(
                color: AppColors.cloud,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _key(k),
                  child: Center(
                    child: k == '<'
                        ? const Icon(Icons.backspace_outlined, semanticLabel: 'Delete', color: AppColors.ink)
                        : Text(k, style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 24)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        PillButton(label: 'Save my number', height: 52, loading: _saving, onPressed: complete ? () => _save(_entry) : null),
        const SizedBox(height: 10),
        PillButton(label: 'Lucky dip', height: 48, style: PillStyle.secondary, onPressed: _saving ? null : () => _save(null)),
      ]),
    );
  }

  Widget _myTicket(Lottery l) {
    final my = l.my!;
    return ChallingoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('YOUR NUMBER', style: Theme.of(context).textTheme.labelSmall)),
          if (l.phase == LotteryPhase.picking)
            TextButton(
              onPressed: () => setState(() {
                _editing = true;
                _entry = my.number;
              }),
              child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
        ]),
        const SizedBox(height: 8),
        TicketDigits(number: my.number, revealed: l.phase == LotteryPhase.settled ? (l.result?.number ?? l.revealed) : l.revealed),
        const SizedBox(height: 10),
        Text(lotteryStatusLine(l), style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _DrawPanel extends StatelessWidget {
  const _DrawPanel({required this.lottery, required this.serverNow});

  final Lottery lottery;
  final DateTime Function() serverNow;

  @override
  Widget build(BuildContext context) {
    final l = lottery;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(colors: [AppColors.ink, AppColors.violetDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TickingBuilder(
          serverNow: serverNow,
          builder: (context, now) {
            final (label, target) = lotteryCountdown(l);
            return Row(children: [
              Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5, color: Colors.white70)),
              const Spacer(),
              if (target != null) LivePill(label: formatDuration(target.difference(now))),
            ]);
          },
        ),
        const SizedBox(height: 16),
        DrawDigits(revealed: l.phase == LotteryPhase.settled ? (l.result?.number ?? l.revealed) : l.revealed, onDark: true),
        const SizedBox(height: 14),
        Row(children: [
          _Stat(value: groupDigits(l.players), label: 'PLAYERS'),
          _Stat(value: l.phase == LotteryPhase.picking ? '–' : groupDigits(l.alive), label: 'STILL IN'),
          _Stat(value: '${l.revealed.length}/10', label: 'DIGITS'),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 22, color: Colors.white)),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white60, letterSpacing: 0.5)),
    ]),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.lottery});

  final Lottery lottery;

  @override
  Widget build(BuildContext context) {
    final r = lottery.result!;
    final won = r.myPrize > 0;
    return ChallingoCard(
      color: won ? AppColors.sun : Colors.white,
      child: Row(children: [
        Tilo(size: 64, mood: won ? TiloMood.cheering : TiloMood.hello),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              won ? 'You won ${groupDigits(r.myPrize)} stars!' : r.rolledOver ? 'No winner today' : 'Winners: ${r.winners}',
              style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 22),
            ),
            Text(
              r.rolledOver
                  ? 'Nobody matched the first digit, so the pot moves to tomorrow.'
                  : '${r.winningMatch} ${r.winningMatch == 1 ? 'digit' : 'digits'} matched · ${groupDigits(r.prizePerWinner)} stars each',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.lottery});

  final Lottery lottery;

  @override
  Widget build(BuildContext context) => ChallingoCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('HOW IT WORKS', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 8),
      for (final line in [
        // Times in the phone's zone: the draw runs on a fixed worldwide clock.
        'Pick a 10-digit number before ${localTime(lottery.picksCloseAtUtc)}. It is free, one number a day.',
        'From ${localTime(lottery.picksCloseAtUtc.add(const Duration(hours: 1)))} one digit of the winning number appears every hour, the last at ${localTime(lottery.endsAtUtc)}.',
        'Your digits must match from the first one. Miss one and you are out.',
        'Whoever matches the most digits shares the pot. If nobody matches the first digit, the pot rolls over.',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 2, right: 8), child: StarIcon(size: 14)),
            Expanded(child: Text(line, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        ),
    ]),
  );
}

class _Fairness extends StatelessWidget {
  const _Fairness({required this.lottery});

  final Lottery lottery;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final r = lottery.result;
    return ChallingoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FAIR DRAW', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        Text('The winning number was fixed before picks opened. This fingerprint was published at the start:', style: small),
        const SizedBox(height: 6),
        SelectableText(lottery.commitHash, style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.w700)),
        if (r != null) ...[
          const SizedBox(height: 8),
          Text('Check it: SHA-256 of "salt:number" equals the fingerprint.', style: small),
          SelectableText('${r.salt}:${r.number}', style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }
}

class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(lotteryHistoryProvider)) {
    AsyncData(value: final draws) when draws.isEmpty => Text('No finished draws yet.', style: Theme.of(context).textTheme.bodySmall),
    AsyncData(value: final draws) => Column(children: [
      for (final d in draws)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.dayKey, style: Theme.of(context).textTheme.bodySmall),
                Text(d.result?.number ?? '', style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 18, letterSpacing: 2)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                d.result == null
                    ? ''
                    : d.result!.rolledOver
                    ? 'Rolled over'
                    : '${d.result!.winners} ${d.result!.winners == 1 ? 'winner' : 'winners'} · ${d.result!.winningMatch} digits',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if ((d.result?.myPrize ?? 0) > 0)
                Text('You won ${groupDigits(d.result!.myPrize)} ★', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.sunDeep))
              else if (d.my != null)
                Text('You matched ${d.my!.match}', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
        ),
    ]),
    _ => const SizedBox.shrink(),
  };
}
