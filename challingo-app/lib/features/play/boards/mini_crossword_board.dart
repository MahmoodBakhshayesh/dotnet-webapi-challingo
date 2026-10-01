import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/challingo/challingo_widgets.dart';
import '../board_context.dart';
import 'board_widgets.dart';

class MiniCrosswordBoard extends StatefulWidget {
  const MiniCrosswordBoard(this.board, {super.key});

  final BoardContext board;

  @override
  State<MiniCrosswordBoard> createState() => _MiniCrosswordBoardState();
}

typedef _Entry = ({int n, List<int> cells, String clue, bool across});

class _MiniCrosswordBoardState extends BoardState<MiniCrosswordBoard> {
  @override
  BoardContext get board => widget.board;

  late final int width = (board.puzzle['width'] as num).toInt();
  late final int height = (board.puzzle['height'] as num).toInt();
  late final Set<int> blocks = intList(board.puzzle['blocks']).toSet();
  late final List<_Entry> entries = [
    for (final across in [true, false])
      for (final e in (board.puzzle[across ? 'across' : 'down'] as List).cast<Map>())
        (n: (e['n'] as num).toInt(), cells: intList(e['cells']), clue: e['clue'] as String, across: across),
  ];
  late final Map<int, int> numbers = {for (final e in entries) e.cells.first: e.n};
  late final List<String> letters = List.filled(width * height, '');
  late _Entry current = entries.first;
  late int cursor = current.cells.first;

  void select(int cell) {
    if (blocks.contains(cell)) return;
    setState(() {
      final candidates = entries.where((e) => e.cells.contains(cell)).toList();
      // Tapping the cursor again switches direction.
      if (cell == cursor && candidates.length > 1) {
        current = candidates.firstWhere((e) => e != current);
      } else if (!current.cells.contains(cell)) {
        current = candidates.firstWhere((e) => e.across == current.across, orElse: () => candidates.first);
      }
      cursor = cell;
    });
  }

  void type(String c) {
    setState(() {
      letters[cursor] = c.toUpperCase();
      final i = current.cells.indexOf(cursor);
      if (i < current.cells.length - 1) cursor = current.cells[i + 1];
    });
    if (!letters.asMap().entries.any((e) => !blocks.contains(e.key) && e.value.isEmpty)) submit();
  }

  void backspace() {
    setState(() {
      if (letters[cursor].isEmpty) {
        final i = current.cells.indexOf(cursor);
        if (i > 0) cursor = current.cells[i - 1];
      }
      letters[cursor] = '';
    });
  }

  void step(int delta) {
    final i = (entries.indexOf(current) + delta) % entries.length;
    setState(() {
      current = entries[i < 0 ? i + entries.length : i];
      cursor = current.cells.firstWhere((c) => letters[c].isEmpty, orElse: () => current.cells.first);
    });
  }

  void submit() => send(() => board.submit({'letters': [for (var i = 0; i < letters.length; i++) blocks.contains(i) ? '#' : (letters[i].isEmpty ? ' ' : letters[i])].join()}));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: Center(
          child: BoardFrame(
            aspectRatio: width / height,
            child: Column(children: [
              for (var r = 0; r < height; r++)
                Expanded(child: Row(children: [for (var c = 0; c < width; c++) Expanded(child: _cell(r * width + c))])),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: AppColors.lilac, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          IconButton(onPressed: () => step(-1), icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Previous clue'),
          Expanded(
            child: Text('${current.n}${current.across ? 'A' : 'D'}  ${current.clue}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          IconButton(onPressed: () => step(1), icon: const Icon(Icons.chevron_right_rounded), tooltip: 'Next clue'),
        ]),
      ),
      const SizedBox(height: 8),
      LetterKeyboard(enabled: !busy, onLetter: type, onBackspace: backspace),
      const SizedBox(height: 8),
      PillButton(label: 'Check', height: 50, loading: busy, onPressed: submit),
    ]);
  }

  Widget _cell(int i) {
    const line = BorderSide(color: Color(0xFFDADCE8));
    if (blocks.contains(i)) return Container(color: AppColors.ink);
    final inEntry = current.cells.contains(i);
    return GestureDetector(
      onTap: () => select(i),
      child: Container(
        decoration: BoxDecoration(
          color: i == cursor ? AppColors.sun : (inEntry ? AppColors.lilac : Colors.white),
          border: const Border(right: line, bottom: line),
        ),
        child: Stack(children: [
          if (numbers[i] != null) Positioned(left: 4, top: 2, child: Text('${numbers[i]}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
          Center(child: Text(letters[i], style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 28))),
        ]),
      ),
    );
  }
}
