import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/challingo/challingo_widgets.dart';
import '../board_context.dart';
import 'board_widgets.dart';
import 'path_link_board.dart';

class CodeBreakerBoard extends StatefulWidget {
  const CodeBreakerBoard(this.board, {super.key});

  final BoardContext board;

  @override
  State<CodeBreakerBoard> createState() => _CodeBreakerBoardState();
}

class _CodeBreakerBoardState extends BoardState<CodeBreakerBoard> {
  @override
  BoardContext get board => widget.board;

  late final int pegs = (board.puzzle['pegs'] as num).toInt();
  late final int colors = (board.puzzle['colors'] as num).toInt();
  late final int maxGuesses = (board.puzzle['maxGuesses'] as num).toInt();
  final List<(List<int>, int, int)> history = [];
  late List<int?> current = List.filled(pegs, null);
  List<int>? code;

  @override
  void initState() {
    super.initState();
    for (final g in ((board.savedState?['guesses'] ?? const []) as List).cast<Map>()) {
      history.add((intList(g['guess']), (g['exact'] as num).toInt(), (g['partial'] as num).toInt()));
    }
  }

  Color colorOf(int c) => PathLinkPalette.colors[c % PathLinkPalette.colors.length];

  void pick(int color) {
    final slot = current.indexOf(null);
    if (slot >= 0) setState(() => current[slot] = color);
  }

  Future<void> guess() async {
    final g = current.cast<int>();
    final result = await send(() => board.move({'guess': g}));
    if (result == null || !mounted) return;
    setState(() {
      history.add((g, (result.response['exact'] as num).toInt(), (result.response['partial'] as num).toInt()));
      current = List.filled(pegs, null);
      if (result.response['code'] != null) code = intList(result.response['code']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('${maxGuesses - history.length} guesses left', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      Expanded(
        child: ListView(
          reverse: true,
          // reverse: the newest guess sits just above the one being built.
          children: [for (final (guess, exact, partial) in history.reversed) _row(guess, exact: exact, partial: partial)],
        ),
      ),
      if (code != null) ...[
        Text('The code', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
        _row(code!),
      ],
      const SizedBox(height: 8),
      // The guess being built: tap a filled slot to clear it.
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < pegs; i++)
          GestureDetector(
            onTap: () => setState(() => current[i] = null),
            child: Container(
              margin: const EdgeInsets.all(6),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current[i] == null ? Colors.white : colorOf(current[i]!),
                border: Border.all(color: current[i] == null ? AppColors.line : Colors.transparent, width: 2.5),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 10),
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        for (var c = 0; c < colors; c++)
          Semantics(
            button: true,
            label: 'Colour ${c + 1}',
            child: GestureDetector(
              onTap: () => pick(c),
              child: Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: colorOf(c), boxShadow: [BoxShadow(color: colorOf(c).withValues(alpha: 0.4), offset: const Offset(0, 3))])),
            ),
          ),
      ]),
      const SizedBox(height: 16),
      PillButton(label: 'Guess', loading: busy, onPressed: current.contains(null) || code != null ? null : guess),
    ]);
  }

  Widget _row(List<int> guess, {int? exact, int? partial}) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Row(children: [
      for (final c in guess) Container(margin: const EdgeInsets.only(right: 8), width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, color: colorOf(c))),
      const Spacer(),
      if (exact != null) ...[
        _feedback(exact, AppColors.mint, 'right place'),
        const SizedBox(width: 8),
        _feedback(partial!, AppColors.sun, 'wrong place'),
      ],
    ]),
  );

  Widget _feedback(int n, Color color, String label) => Semantics(
    label: '$n $label',
    child: Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text('$n', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    ]),
  );
}
