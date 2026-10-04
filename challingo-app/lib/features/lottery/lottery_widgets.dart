import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/competition_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../boards/board_widgets.dart';
import '../competition/competition_providers.dart';
import '../competition/competition_widgets.dart';

enum DigitLook { hidden, revealed, matched, missed, entered, empty }

/// One digit slot of the draw or a ticket.
class DigitTile extends StatelessWidget {
  const DigitTile({super.key, required this.digit, required this.look, this.size = 30, this.onDark = false});

  final String? digit;
  final DigitLook look;
  final double size;

  /// On the dark lottery card.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (look) {
      DigitLook.revealed => (AppColors.sun, AppColors.ink, null),
      DigitLook.matched => (AppColors.mint, Colors.white, null),
      DigitLook.missed => (AppColors.berry, Colors.white, null),
      DigitLook.entered => (Colors.white, AppColors.ink, AppColors.violet),
      DigitLook.empty => (Colors.white, AppColors.inkMuted, AppColors.line),
      DigitLook.hidden => (onDark ? Colors.white.withValues(alpha: 0.12) : AppColors.lineSoft, onDark ? Colors.white54 : AppColors.inkMuted, null),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      width: size,
      height: size * 1.25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: border == null ? null : Border.all(color: border, width: 2),
      ),
      child: Text(
        digit ?? (look == DigitLook.hidden ? '?' : ''),
        style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: size * 0.62, color: fg),
      ),
    );
  }
}

/// The draw's ten digits: revealed ones in gold, the rest hidden.
class DrawDigits extends StatelessWidget {
  const DrawDigits({super.key, required this.revealed, this.onDark = false});

  final String revealed;
  final bool onDark;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = ((constraints.maxWidth - 9 * 5) / 10).clamp(18.0, 34.0);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < Lottery.digits; i++)
            DigitTile(
              digit: i < revealed.length ? revealed[i] : null,
              look: i < revealed.length ? DigitLook.revealed : DigitLook.hidden,
              size: size,
              onDark: onDark,
            ),
        ],
      );
    },
  );
}

/// A ticket against the revealed digits: green while matching, red at the first miss, grey after that.
class TicketDigits extends StatelessWidget {
  const TicketDigits({super.key, required this.number, required this.revealed});

  final String number;
  final String revealed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = ((constraints.maxWidth - 9 * 5) / 10).clamp(18.0, 34.0);
      var missed = false;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < number.length; i++)
            () {
              DigitLook look;
              if (missed || i >= revealed.length) {
                look = DigitLook.empty;
              } else if (number[i] == revealed[i]) {
                look = DigitLook.matched;
              } else {
                look = DigitLook.missed;
                missed = true;
              }
              return DigitTile(digit: number[i], look: look, size: size);
            }(),
        ],
      );
    },
  );
}

/// What the countdown on the card and page counts to.
(String, DateTime?) lotteryCountdown(Lottery l) => switch (l.phase) {
  LotteryPhase.picking => ('Picks close in', l.picksCloseAtUtc),
  LotteryPhase.revealing => (l.nextRevealAtUtc == null ? 'Last digit soon' : 'Next digit in', l.nextRevealAtUtc),
  LotteryPhase.settled => ('Settled', null),
};

String lotteryStatusLine(Lottery l) {
  final my = l.my;
  switch (l.phase) {
    case LotteryPhase.picking:
      return my == null ? 'Pick your lucky number before ${localTime(l.picksCloseAtUtc)}' : 'Your number: ${my.number}';
    case LotteryPhase.revealing:
      if (my == null) {
        return l.players == 0 ? 'No picks today. A new draw opens at ${localTime(l.endsAtUtc)}.' : '${groupDigits(l.alive)} of ${groupDigits(l.players)} players still in';
      }
      return my.alive
          ? "You're still in! ${my.match} matched · ${groupDigits(l.alive)} left"
          : 'Out after ${my.match} ${my.match == 1 ? 'digit' : 'digits'} · ${groupDigits(l.alive)} still in';
    case LotteryPhase.settled:
      final r = l.result;
      if (r == null) return 'Draw finished';
      if (r.myPrize > 0) return 'You won ${groupDigits(r.myPrize)} stars!';
      return r.rolledOver ? 'No winner: the pot rolls over' : '${r.winners} ${r.winners == 1 ? 'winner' : 'winners'} · ${groupDigits(r.prizePerWinner)} stars each';
  }
}

/// Home card: always visible, live countdown and digits; opens the lottery page.
class LotteryCard extends ConsumerWidget {
  const LotteryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lottery = ref.watch(lotteryProvider).value;
    if (lottery == null) return const SizedBox.shrink();
    final serverNow = ref.read(lobbyProvider.notifier).serverNow;
    return Semantics(
      button: true,
      label: 'Daily draw',
      child: GestureDetector(
        onTap: () => context.push('/lottery'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(colors: [AppColors.ink, AppColors.violetDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Text('DAILY DRAW', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5, color: Colors.white)),
              const SizedBox(width: 8),
              StatPill.stars(groupDigits(lottery.pot)),
              const Spacer(),
              TickingBuilder(
                serverNow: serverNow,
                builder: (context, now) {
                  final (label, target) = lotteryCountdown(lottery);
                  return Text(
                    target == null ? label : '$label ${formatDuration(target.difference(now))}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white70, fontFeatures: [FontFeature.tabularFigures()]),
                  );
                },
              ),
            ]),
            const SizedBox(height: 14),
            DrawDigits(revealed: lottery.revealed, onDark: true),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(lotteryStatusLine(lottery), style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ]),
          ]),
        ),
      ),
    );
  }
}
