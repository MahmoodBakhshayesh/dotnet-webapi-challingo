import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/challingo/challingo_widgets.dart';
import '../board_context.dart';
import 'board_widgets.dart';

class KakuroBoard extends StatefulWidget {
  const KakuroBoard(this.board, {super.key});

  final BoardContext board;

  @override
  State<KakuroBoard> createState() => _KakuroBoardState();
}

class _KakuroBoardState extends BoardState<KakuroBoard> {
  @override
  BoardContext get board => widget.board;

  late final int size = (board.puzzle['size'] as num).toInt();
  late final List<Map<String, dynamic>> grid = (board.puzzle['grid'] as List).cast<Map<String, dynamic>>();
  late final List<int> cells = List.filled(size * size, 0);
  int? selected;

  bool white(int i) => grid[i]['t'] == 'w';

  /// The run of white cells through [i] in one direction.
  List<int> run(int i, bool across) {
    final step = across ? 1 : size;
    bool inLine(int j) => across ? j ~/ size == i ~/ size : true;
    var start = i;
    while (start - step >= 0 && inLine(start - step) && white(start - step)) {
      start -= step;
    }
    final out = <int>[];
    for (var j = start; j < cells.length && inLine(j) && white(j); j += step) {
      out.add(j);
    }
    return out;
  }

  Set<int> get conflicts {
    final out = <int>{};
    for (var i = 0; i < cells.length; i++) {
      if (!white(i) || cells[i] == 0) continue;
      for (final across in [true, false]) {
        if (run(i, across).where((j) => j != i && cells[j] == cells[i]).isNotEmpty) out.add(i);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final bad = conflicts;
    final full = List.generate(cells.length, (i) => !white(i) || cells[i] != 0).every((x) => x);
    return Column(children: [
      Expanded(
        child: Center(
          child: BoardFrame(
            child: Column(children: [
              for (var r = 0; r < size; r++)
                Expanded(child: Row(children: [for (var c = 0; c < size; c++) _cell(r * size + c, bad)])),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 16),
      DigitPad(
        digits: List.generate(9, (i) => i + 1),
        onDigit: (d) => selected == null ? null : setState(() => cells[selected!] = d),
        onErase: () => selected == null ? null : setState(() => cells[selected!] = 0),
      ),
      const SizedBox(height: 12),
      PillButton(label: 'Submit', loading: busy, onPressed: full && bad.isEmpty ? () => send(() => board.submit({'cells': cells})) : null),
    ]);
  }

  Widget _cell(int i, Set<int> bad) {
    final e = grid[i];
    const line = BorderSide(color: Color(0xFFDADCE8));
    if (e['t'] != 'w') {
      final across = e['a'], down = e['d'];
      return Expanded(
        child: Container(
          decoration: const BoxDecoration(color: AppColors.ink, border: Border(right: BorderSide(color: Color(0xFF34324D)), bottom: BorderSide(color: Color(0xFF34324D)))),
          child: e['t'] == 'b'
              ? null
              : CustomPaint(
                  painter: _DiagonalPainter(),
                  child: Stack(children: [
                    if (across != null)
                      Positioned(right: 4, top: 2, child: Text('$across', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
                    if (down != null)
                      Positioned(left: 4, bottom: 2, child: Text('$down', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
                  ]),
                ),
        ),
      );
    }
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selected = i),
        child: Container(
          decoration: BoxDecoration(color: selected == i ? AppColors.lilac : Colors.white, border: const Border(right: line, bottom: line)),
          alignment: Alignment.center,
          child: cells[i] == 0
              ? null
              : FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text('${cells[i]}',
                        style: TextStyle(fontFamily: AppTheme.display, fontSize: 26, fontWeight: FontWeight.w600, color: bad.contains(i) ? AppColors.berry : AppColors.violet)),
                  ),
                ),
        ),
      ),
    );
  }
}

class _DiagonalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawLine(Offset.zero, Offset(size.width, size.height), Paint()..color = const Color(0xFF5D5F78)..strokeWidth = 1);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
