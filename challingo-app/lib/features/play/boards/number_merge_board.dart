import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../board_context.dart';
import 'board_widgets.dart';

/// mulberry32, bit-for-bit the server's (Challingo.Core NumberMerge.Mulberry32). Native ints only (not web).
class Mulberry32 {
  Mulberry32(this._a);

  int _a;

  int next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = ((_a ^ (_a >> 15)) * (1 | _a)) & 0xFFFFFFFF;
    t = ((t + (((t ^ (t >> 7)) * (61 | t)) & 0xFFFFFFFF)) & 0xFFFFFFFF) ^ t;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  int below(int n) => next() % n;
}

/// 2048 board with the shared spawn rule: empty cells row-major, index = next() % count, value = next() % 10 == 0 ? 4 : 2.
class MergeBoard {
  MergeBoard(this.size, int seed) : _rng = Mulberry32(seed), cells = List.filled(size * size, 0) {
    _spawn();
    _spawn();
  }

  final int size;
  final Mulberry32 _rng;
  final List<int> cells;

  int get maxTile => cells.reduce((a, b) => a > b ? a : b);

  /// L/R/U/D; false (and no spawn) when nothing moved.
  bool move(String direction) {
    var changed = false;
    for (var line = 0; line < size; line++) {
      final idx = List.generate(size, (k) => switch (direction) {
        'L' => line * size + k,
        'R' => line * size + (size - 1 - k),
        'U' => k * size + line,
        _ => (size - 1 - k) * size + line,
      });
      final values = idx.map((i) => cells[i]).where((v) => v != 0).toList();
      final merged = <int>[];
      for (var k = 0; k < values.length; k++) {
        if (k + 1 < values.length && values[k] == values[k + 1]) {
          merged.add(values[k] * 2);
          k++;
        } else {
          merged.add(values[k]);
        }
      }
      for (var k = 0; k < size; k++) {
        final v = k < merged.length ? merged[k] : 0;
        if (cells[idx[k]] != v) {
          cells[idx[k]] = v;
          changed = true;
        }
      }
    }
    if (changed) _spawn();
    return changed;
  }

  void _spawn() {
    final empty = [for (var i = 0; i < cells.length; i++) if (cells[i] == 0) i];
    if (empty.isEmpty) return;
    final at = empty[_rng.below(empty.length)];
    cells[at] = _rng.below(10) == 0 ? 4 : 2;
  }
}

class NumberMergeBoard extends StatefulWidget {
  const NumberMergeBoard(this.board, {super.key});

  final BoardContext board;

  @override
  State<NumberMergeBoard> createState() => _NumberMergeBoardState();
}

class _NumberMergeBoardState extends BoardState<NumberMergeBoard> {
  @override
  BoardContext get board => widget.board;

  late final int size = (board.puzzle['size'] as num).toInt();
  late final int target = (board.puzzle['target'] as num).toInt();
  late final int seed = (board.puzzle['seed'] as num).toInt();
  late MergeBoard game = MergeBoard(size, seed);
  final StringBuffer moves = StringBuffer();
  bool done = false;

  void swipe(String direction) {
    if (done || !game.move(direction)) return;
    setState(() => moves.write(direction));
    if (game.maxTile >= target) {
      done = true;
      send(() => board.submit({'moves': moves.toString()}));
    }
  }

  void restart() => setState(() {
    game = MergeBoard(size, seed);
    moves.clear();
    done = false;
  });

  @override
  Widget build(BuildContext context) {
    final stuck = !done && game.cells.every((v) => v != 0) && !_canMerge();
    return Column(children: [
      Text('Reach $target', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
      Text('${moves.length} moves · fewest moves wins', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      Expanded(
        child: Center(
          child: GestureDetector(
            onPanEnd: (d) {
              final v = d.velocity.pixelsPerSecond;
              if (v.distance < 100) return;
              swipe(v.dx.abs() > v.dy.abs() ? (v.dx > 0 ? 'R' : 'L') : (v.dy > 0 ? 'D' : 'U'));
            },
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.lineSoft, borderRadius: BorderRadius.circular(22)),
                child: GridView.count(
                  crossAxisCount: size,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [for (final v in game.cells) _tile(v)],
                ),
              ),
            ),
          ),
        ),
      ),
      if (stuck) ...[
        const SizedBox(height: 8),
        Text('No moves left — restart to try again (the clock keeps running).', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ],
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ToolChip(icon: Icons.restart_alt_rounded, label: 'Restart', onTap: done ? null : restart),
      ]),
    ]);
  }

  bool _canMerge() {
    for (var i = 0; i < game.cells.length; i++) {
      if (i % size < size - 1 && game.cells[i] == game.cells[i + 1]) return true;
      if (i + size < game.cells.length && game.cells[i] == game.cells[i + size]) return true;
    }
    return false;
  }

  Widget _tile(int v) {
    final level = v == 0 ? 0 : (v.bitLength - 1); // 2 → 1, 4 → 2, …
    final colors = [Colors.white, const Color(0xFFEEEBFF), const Color(0xFFDCD6FF), const Color(0xFFFFE6E2), const Color(0xFFFFC9BF), AppColors.coral, const Color(0xFFFFE08A), AppColors.sun, const Color(0xFF8E80FF), AppColors.violet, AppColors.violetDark];
    final bg = v == 0 ? Colors.white.withValues(alpha: 0.5) : colors[level.clamp(0, colors.length - 1)];
    final dark = level >= 8 || level == 5;
    return Padding(
      padding: const EdgeInsets.all(5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: v == 0
            ? null
            : FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('$v', style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 30, color: dark ? Colors.white : AppColors.ink)),
                ),
              ),
      ),
    );
  }
}
