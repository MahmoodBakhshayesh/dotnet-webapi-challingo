import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/challingo/challingo_widgets.dart';
import '../board_context.dart';
import 'board_widgets.dart';

class NonogramBoard extends StatefulWidget {
  const NonogramBoard(this.board, {super.key});

  final BoardContext board;

  @override
  State<NonogramBoard> createState() => _NonogramBoardState();
}

/// 0 empty, 1 filled, 2 marked "definitely empty" (only on the device).
class _NonogramBoardState extends BoardState<NonogramBoard> {
  @override
  BoardContext get board => widget.board;

  late final int width = (board.puzzle['width'] as num).toInt();
  late final int height = (board.puzzle['height'] as num).toInt();
  late final List<List<int>> rows = (board.puzzle['rows'] as List).map(intList).toList();
  late final List<List<int>> cols = (board.puzzle['cols'] as List).map(intList).toList();
  late final List<int> cells = List.filled(width * height, 0);
  bool markMode = false;
  int? _dragValue;

  static List<int> clue(Iterable<int> line) {
    final runs = <int>[];
    var run = 0;
    for (final v in line) {
      if (v == 1) {
        run++;
      } else if (run > 0) {
        runs.add(run);
        run = 0;
      }
    }
    if (run > 0) runs.add(run);
    return runs.isEmpty ? [0] : runs;
  }

  bool rowDone(int r) => _same(clue(cells.sublist(r * width, (r + 1) * width)), rows[r]);
  bool colDone(int c) => _same(clue([for (var r = 0; r < height; r++) cells[r * width + c]]), cols[c]);
  static bool _same(List<int> a, List<int> b) => a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);

  void paint(int i, {bool start = false}) {
    final target = markMode ? 2 : 1;
    if (start) _dragValue = cells[i] == target ? 0 : target;
    setState(() => cells[i] = _dragValue ?? target);
    if (List.generate(height, rowDone).every((x) => x) && List.generate(width, colDone).every((x) => x)) {
      send(() => board.submit({'cells': cells.map((v) => v == 1 ? 1 : 0).toList()}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rowClueWidth = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b) * 16.0 + 10;
    final colClueHeight = cols.map((c) => c.length).reduce((a, b) => a > b ? a : b) * 16.0 + 8;
    return Column(children: [
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final cell = ((box.maxWidth - rowClueWidth) / width).clamp(0.0, (box.maxHeight - colClueHeight) / height);
          int? hit(Offset p) {
            final c = ((p.dx - rowClueWidth) / cell).floor(), r = ((p.dy - colClueHeight) / cell).floor();
            return (c >= 0 && c < width && r >= 0 && r < height) ? r * width + c : null;
          }

          return Center(
            child: GestureDetector(
              onPanStart: (d) {
                final i = hit(d.localPosition);
                if (i != null) paint(i, start: true);
              },
              onPanUpdate: (d) {
                final i = hit(d.localPosition);
                if (i != null) paint(i);
              },
              onTapUp: (d) {
                final i = hit(d.localPosition);
                if (i != null) paint(i, start: true);
              },
              child: SizedBox(
                width: rowClueWidth + cell * width,
                height: colClueHeight + cell * height,
                child: Stack(children: [
                  for (var c = 0; c < width; c++)
                    Positioned(
                      left: rowClueWidth + c * cell,
                      top: 0,
                      width: cell,
                      height: colClueHeight - 4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [for (final n in cols[c]) Text('$n', style: _clueStyle(colDone(c)))],
                      ),
                    ),
                  for (var r = 0; r < height; r++)
                    Positioned(
                      left: 0,
                      top: colClueHeight + r * cell,
                      width: rowClueWidth - 6,
                      height: cell,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [for (final n in rows[r]) Padding(padding: const EdgeInsets.only(left: 6), child: Text('$n', style: _clueStyle(rowDone(r))))],
                      ),
                    ),
                  Positioned(
                    left: rowClueWidth,
                    top: colClueHeight,
                    width: cell * width,
                    height: cell * height,
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2.5), borderRadius: BorderRadius.circular(8)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(children: [
                        for (var r = 0; r < height; r++)
                          Expanded(child: Row(children: [for (var c = 0; c < width; c++) Expanded(child: _cell(r, c))])),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ToolChip(icon: Icons.square_rounded, label: 'Fill', selected: !markMode, onTap: () => setState(() => markMode = false)),
        const SizedBox(width: 10),
        ToolChip(icon: Icons.close_rounded, label: 'Mark empty', selected: markMode, onTap: () => setState(() => markMode = true)),
      ]),
      const SizedBox(height: 16),
      PillButton(label: 'Check', loading: busy, onPressed: () => send(() => board.submit({'cells': cells.map((v) => v == 1 ? 1 : 0).toList()}))),
    ]);
  }

  TextStyle _clueStyle(bool done) =>
      TextStyle(fontWeight: FontWeight.w800, fontSize: 13, height: 1.2, color: done ? AppColors.inkMuted.withValues(alpha: 0.5) : AppColors.ink);

  Widget _cell(int r, int c) {
    final v = cells[r * width + c];
    final side = BorderSide(color: const Color(0xFFDADCE8), width: (c + 1) % 5 == 0 ? 1.5 : 0.5);
    return Container(
      decoration: BoxDecoration(
        color: v == 1 ? AppColors.violet : Colors.white,
        border: Border(right: side, bottom: BorderSide(color: const Color(0xFFDADCE8), width: (r + 1) % 5 == 0 ? 1.5 : 0.5)),
      ),
      child: v == 2 ? const Icon(Icons.close_rounded, size: 14, color: AppColors.inkMuted) : null,
    );
  }
}
