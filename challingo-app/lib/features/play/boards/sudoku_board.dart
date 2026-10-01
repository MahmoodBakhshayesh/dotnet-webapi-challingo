import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/challingo/challingo_widgets.dart';
import '../board_context.dart';
import 'board_widgets.dart';

class SudokuBoard extends StatefulWidget {
  const SudokuBoard(this.board, {super.key});

  final BoardContext board;

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends BoardState<SudokuBoard> {
  @override
  BoardContext get board => widget.board;

  late final int size = (board.puzzle['size'] as num).toInt();
  late final int boxRows = (board.puzzle['boxRows'] as num).toInt();
  late final int boxCols = (board.puzzle['boxCols'] as num).toInt();
  late final List<int> givens = intList(board.puzzle['givens']);
  late final List<int> cells = List.of(givens);
  int? selected;

  int box(int i) => (i ~/ size) ~/ boxRows * (size ~/ boxCols) + (i % size) ~/ boxCols;

  /// Cells whose digit repeats in their row, column or box.
  Set<int> get conflicts {
    final out = <int>{};
    for (var a = 0; a < cells.length; a++) {
      for (var b = a + 1; b < cells.length; b++) {
        if (cells[a] == 0 || cells[a] != cells[b]) continue;
        if (a ~/ size == b ~/ size || a % size == b % size || box(a) == box(b)) out.addAll([a, b]);
      }
    }
    return out;
  }

  void put(int digit) {
    final s = selected;
    if (s == null || givens[s] != 0) return;
    setState(() => cells[s] = digit);
  }

  @override
  Widget build(BuildContext context) {
    final bad = conflicts;
    final full = !cells.contains(0);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: BoardFrame(
              child: Column(children: [
                for (var r = 0; r < size; r++)
                  Expanded(
                    child: Row(children: [
                      for (var c = 0; c < size; c++) _cell(r * size + c, bad),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DigitPad(digits: List.generate(size, (i) => i + 1), onDigit: put, onErase: () => put(0)),
        const SizedBox(height: 16),
        PillButton(
          label: 'Submit',
          loading: busy,
          onPressed: full && bad.isEmpty ? () => send(() => board.submit({'cells': cells})) : null,
        ),
      ],
    );
  }

  Widget _cell(int i, Set<int> bad) {
    final r = i ~/ size, c = i % size;
    final given = givens[i] != 0;
    final thick = BorderSide(color: AppColors.ink, width: 3);
    const thin = BorderSide(color: Color(0xFFDADCE8));
    return Expanded(
      child: GestureDetector(
        onTap: given ? null : () => setState(() => selected = i),
        child: Container(
          decoration: BoxDecoration(
            color: selected == i ? AppColors.lilac : (given ? AppColors.cloud : Colors.white),
            border: Border(
              right: c == size - 1 ? BorderSide.none : ((c + 1) % boxCols == 0 ? thick : thin),
              bottom: r == size - 1 ? BorderSide.none : ((r + 1) % boxRows == 0 ? thick : thin),
            ),
          ),
          alignment: Alignment.center,
          child: cells[i] == 0
              ? null
              : FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      '${cells[i]}',
                      style: TextStyle(
                        fontFamily: AppTheme.display,
                        fontSize: 30,
                        fontWeight: given ? FontWeight.w700 : FontWeight.w600,
                        color: bad.contains(i) ? AppColors.berry : (given ? AppColors.ink : AppColors.violet),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
