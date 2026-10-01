import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../board_context.dart';
import 'board_widgets.dart';

/// Distinct game colours (Path Link pairs, Code Breaker pegs); they also differ in lightness.
abstract final class PathLinkPalette {
  static const colors = [
    AppColors.violet, AppColors.coral, Color(0xFFE6A700), AppColors.mint,
    Color(0xFF2F80ED), Color(0xFFD94FAE), Color(0xFF0E9F8F), Color(0xFF8D5524),
  ];
}

class PathLinkBoard extends StatefulWidget {
  const PathLinkBoard(this.board, {super.key});

  final BoardContext board;

  @override
  State<PathLinkBoard> createState() => _PathLinkBoardState();
}

class _PathLinkBoardState extends BoardState<PathLinkBoard> {
  @override
  BoardContext get board => widget.board;

  static const palette = PathLinkPalette.colors;

  late final int size = (board.puzzle['size'] as num).toInt();
  late final List<List<int>> dots = (board.puzzle['dots'] as List).map(intList).toList();
  late final List<List<int>> paths = List.generate(dots.length, (_) => <int>[]);
  late final Map<int, int> dotColor = {for (var k = 0; k < dots.length; k++) for (final d in dots[k]) d: k};
  int? active;
  bool submitted = false;

  bool adjacent(int a, int b) => (a ~/ size - b ~/ size).abs() + (a % size - b % size).abs() == 1;
  bool complete(int k) => paths[k].length > 1 && dotColor[paths[k].first] == k && dotColor[paths[k].last] == k && paths[k].first != paths[k].last;
  int? ownerOf(int cell) {
    final k = paths.indexWhere((p) => p.contains(cell));
    return k >= 0 ? k : null;
  }

  void start(int cell) {
    final dot = dotColor[cell];
    if (dot != null) {
      setState(() {
        paths[dot] = [cell];
        active = dot;
      });
      return;
    }
    final k = ownerOf(cell);
    if (k == null) return;
    setState(() {
      paths[k] = paths[k].sublist(0, paths[k].indexOf(cell) + 1);
      active = k;
    });
  }

  void extend(int cell) {
    final k = active;
    if (k == null) return;
    final path = paths[k];
    if (path.isEmpty || cell == path.last || !adjacent(cell, path.last)) return;

    setState(() {
      final at = path.indexOf(cell);
      if (at >= 0) {
        path.removeRange(at + 1, path.length); // drag back over the path: undo
        return;
      }
      if (complete(k)) return;
      final dot = dotColor[cell];
      if (dot != null && dot != k) return; // other colours' dots block
      final other = ownerOf(cell);
      if (other != null) {
        paths[other].removeRange(paths[other].indexOf(cell), paths[other].length); // cut the crossed path
      }
      path.add(cell);
    });
  }

  void end() {
    active = null;
    final covered = paths.fold<int>(0, (n, p) => n + p.length);
    if (!submitted && covered == size * size && List.generate(paths.length, complete).every((x) => x)) {
      submitted = true;
      send(() => board.submit({'paths': paths})).then((r) => submitted = r?.message == null && r != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filled = paths.fold<int>(0, (n, p) => n + p.length);
    return Column(children: [
      Expanded(
        child: Center(
          child: BoardFrame(
            child: LayoutBuilder(builder: (context, box) {
              final cell = box.maxWidth / size;
              int? hit(Offset p) {
                final c = (p.dx / cell).floor(), r = (p.dy / cell).floor();
                return c >= 0 && c < size && r >= 0 && r < size ? r * size + c : null;
              }

              return GestureDetector(
                onPanStart: (d) => hit(d.localPosition) == null ? null : start(hit(d.localPosition)!),
                onPanUpdate: (d) => hit(d.localPosition) == null ? null : extend(hit(d.localPosition)!),
                onPanEnd: (_) => end(),
                child: CustomPaint(size: Size.square(box.maxWidth), painter: _PathPainter(size, dots, paths, palette)),
              );
            }),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        '${(filled * 100 / (size * size)).round()}% filled · ${List.generate(paths.length, complete).where((x) => x).length}/${dots.length} linked',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text('Drag from a dot to its twin. Every square must be used.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.size, this.dots, this.paths, this.palette);

  final int size;
  final List<List<int>> dots;
  final List<List<int>> paths;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size box) {
    final cell = box.width / size;
    Offset center(int i) => Offset((i % size + 0.5) * cell, (i ~/ size + 0.5) * cell);

    final grid = Paint()..color = const Color(0xFFDADCE8)..strokeWidth = 1;
    for (var i = 1; i < size; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, box.height), grid);
      canvas.drawLine(Offset(0, i * cell), Offset(box.width, i * cell), grid);
    }

    for (var k = 0; k < paths.length; k++) {
      final color = palette[k % palette.length];
      for (final c in paths[k]) {
        canvas.drawRect(Rect.fromCenter(center: center(c), width: cell, height: cell), Paint()..color = color.withValues(alpha: 0.14));
      }
      if (paths[k].length > 1) {
        final line = Path()..moveTo(center(paths[k].first).dx, center(paths[k].first).dy);
        for (final c in paths[k].skip(1)) {
          line.lineTo(center(c).dx, center(c).dy);
        }
        canvas.drawPath(line, Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.32
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
      }
      for (final d in dots[k]) {
        canvas.drawCircle(center(d), cell * 0.34, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => true;
}
