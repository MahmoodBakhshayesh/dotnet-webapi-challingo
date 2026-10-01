import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../board_context.dart';
import 'board_widgets.dart';

class MineLogicBoard extends StatefulWidget {
  const MineLogicBoard(this.board, {super.key});

  final BoardContext board;

  @override
  State<MineLogicBoard> createState() => _MineLogicBoardState();
}

/// Tap reveals (the server answers), long-press flags (flags stay on the device).
class _MineLogicBoardState extends BoardState<MineLogicBoard> {
  @override
  BoardContext get board => widget.board;

  late final int width = (board.puzzle['width'] as num).toInt();
  late final int height = (board.puzzle['height'] as num).toInt();
  late final int mineCount = (board.puzzle['mines'] as num).toInt();
  final Map<int, int> numbers = {};
  final Set<int> flags = {};
  Set<int> mines = {};

  @override
  void initState() {
    super.initState();
    final cells = (board.savedState?['revealed'] ?? board.puzzle['opening']) as List;
    for (final c in cells.cast<Map>()) {
      numbers[(c['i'] as num).toInt()] = (c['n'] as num).toInt();
    }
  }

  Future<void> reveal(int i) async {
    if (numbers.containsKey(i) || flags.contains(i)) return;
    final result = await send(() => board.move({'reveal': i}));
    if (result == null || !mounted) return;
    setState(() {
      if (result.response['mine'] == true) {
        mines = intList(result.response['mines']).toSet();
      } else {
        for (final c in (result.response['revealed'] as List).cast<Map>()) {
          numbers[(c['i'] as num).toInt()] = (c['n'] as num).toInt();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.flag_rounded, color: AppColors.coral),
        const SizedBox(width: 6),
        Text('${mineCount - flags.length} mines left', style: Theme.of(context).textTheme.titleMedium),
      ]),
      const SizedBox(height: 12),
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
      Text('Tap to reveal · press and hold to flag', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Widget _cell(int i) {
    const line = BorderSide(color: Color(0xFFDADCE8), width: 0.8);
    final n = numbers[i];
    final isMine = mines.contains(i);
    return GestureDetector(
      onTap: busy ? null : () => reveal(i),
      onLongPress: n != null ? null : () => setState(() => flags.contains(i) ? flags.remove(i) : flags.add(i)),
      child: Container(
        decoration: BoxDecoration(
          color: isMine ? AppColors.berry : (n != null ? Colors.white : AppColors.lilac),
          border: const Border(right: line, bottom: line),
        ),
        alignment: Alignment.center,
        child: isMine
            ? const Icon(Icons.brightness_7_rounded, color: Colors.white, size: 18)
            : flags.contains(i)
            ? const Icon(Icons.flag_rounded, color: AppColors.coral, size: 18)
            : (n == null || n == 0)
            ? null
            : Text('$n', style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 20, color: _numberColor(n))),
      ),
    );
  }

  static Color _numberColor(int n) => switch (n) {
    1 => AppColors.violet,
    2 => AppColors.mint,
    3 => AppColors.coral,
    _ => AppColors.ink,
  };
}
