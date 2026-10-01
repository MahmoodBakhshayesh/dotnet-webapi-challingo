import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/challingo/challingo_widgets.dart';
import '../board_context.dart';

class WordHuntBoard extends StatefulWidget {
  const WordHuntBoard(this.board, {super.key});

  final BoardContext board;

  @override
  State<WordHuntBoard> createState() => _WordHuntBoardState();
}

/// Swipe across neighbouring tiles; every word goes to the server, which scores it against its own clock.
class _WordHuntBoardState extends BoardState<WordHuntBoard> {
  @override
  BoardContext get board => widget.board;

  late final int size = (board.puzzle['size'] as num).toInt();
  late final List<String> tiles = (board.puzzle['tiles'] as List).cast<String>();
  late final int limitSeconds = (board.puzzle['timeLimitSeconds'] as num).toInt();
  final List<(String, int)> found = [];
  final List<int> path = [];
  int score = 0;
  String? flash;
  bool flashGood = false;
  bool ended = false;

  @override
  void initState() {
    super.initState();
    final saved = board.savedState;
    if (saved != null) {
      for (final f in (saved['found'] as List).cast<Map>()) {
        found.add((f['word'] as String, (f['points'] as num).toInt()));
      }
      score = (saved['score'] as num).toInt();
    }
  }

  String get word => path.map((i) => tiles[i]).join();

  bool adjacent(int a, int b) => (a ~/ size - b ~/ size).abs() <= 1 && (a % size - b % size).abs() <= 1;

  void touch(int cell) {
    if (path.isNotEmpty && path.last == cell) return;
    setState(() {
      if (path.length > 1 && path[path.length - 2] == cell) {
        path.removeLast(); // slide back to undo the last tile
      } else if (!path.contains(cell) && (path.isEmpty || adjacent(path.last, cell))) {
        path.add(cell);
      }
    });
  }

  Future<void> release() async {
    if (path.isEmpty) return;
    final swiped = List.of(path);
    setState(path.clear);
    if (swiped.length < 2 || ended) return;
    final result = await board.move({'path': swiped}).then<Map<String, dynamic>?>((r) => r.response).catchError((Object e) {
      board.notify(e.toString());
      return null;
    });
    if (result == null || !mounted) return;
    setState(() {
      final valid = result['valid'] == true;
      final w = (result['word'] as String? ?? '').toUpperCase();
      flashGood = valid;
      flash = valid
          ? '+${result['points']}  $w'
          : switch (result['reason']) {
              'repeat' => '$w — already found',
              'short' => 'Too short',
              'time' => "Time's up",
              _ => '$w — not a word',
            };
      if (valid) {
        found.insert(0, (result['word'] as String, (result['points'] as num).toInt()));
        score = (result['score'] as num).toInt();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final remaining = Duration(seconds: limitSeconds) - board.elapsed;
    if (remaining <= Duration.zero && !ended) {
      ended = true;
      SchedulerBinding.instance.addPostFrameCallback((_) => send(() => board.submit({})));
    }
    final text = Theme.of(context).textTheme;
    return Column(children: [
      Row(children: [
        Text('$score', style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 34)),
        const SizedBox(width: 6),
        Text('points · ${found.length} words', style: text.bodySmall),
        const Spacer(),
        if (flash != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: flashGood ? AppColors.mint : AppColors.coralSoft, borderRadius: BorderRadius.circular(999)),
            child: Text(flash!, style: TextStyle(fontWeight: FontWeight.w800, color: flashGood ? Colors.white : AppColors.ink)),
          ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 36,
        child: Center(
          child: Text(word.toUpperCase(), style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 28, color: AppColors.violet, letterSpacing: 2)),
        ),
      ),
      const SizedBox(height: 8),
      AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (context, box) {
          final cell = box.maxWidth / size;
          // Only count a tile when the finger is near its centre, so diagonal swipes don't clip neighbours.
          int? hit(Offset p) {
            final c = (p.dx / cell).floor(), r = (p.dy / cell).floor();
            if (c < 0 || c >= size || r < 0 || r >= size) return null;
            final center = Offset((c + 0.5) * cell, (r + 0.5) * cell);
            return (p - center).distance <= cell * 0.38 ? r * size + c : null;
          }

          return GestureDetector(
            onPanStart: (d) => hit(d.localPosition) == null ? null : touch(hit(d.localPosition)!),
            onPanUpdate: (d) => hit(d.localPosition) == null ? null : touch(hit(d.localPosition)!),
            onPanEnd: (_) => release(),
            child: GridView.count(
              crossAxisCount: size,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < tiles.length; i++)
                  Padding(
                    padding: EdgeInsets.all(cell * 0.06),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      decoration: BoxDecoration(
                        color: path.contains(i) ? AppColors.violet : Colors.white,
                        borderRadius: BorderRadius.circular(cell * 0.22),
                        boxShadow: [BoxShadow(color: path.contains(i) ? AppColors.violetDark : AppColors.line, offset: const Offset(0, 4))],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tiles[i] == 'qu' ? 'Qu' : tiles[i].toUpperCase(),
                        style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: cell * 0.42, color: path.contains(i) ? Colors.white : AppColors.ink),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (w, p) in found.take(24))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
              child: Text('${w.toUpperCase()} $p', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
        ]),
      ),
      PillButton(label: 'Finish', style: PillStyle.secondary, height: 50, loading: busy, onPressed: ended ? null : () => send(() => board.submit({}))),
    ]);
  }
}
