import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// One cell of a demo frame.
class DemoCell {
  const DemoCell(this.text, {this.fill, this.textColor, this.round = false, this.small = false, this.hidden = false});

  final String text;
  final Color? fill;
  final Color? textColor;

  /// Drawn as a circle (code pegs, path dots).
  final bool round;

  /// Smaller text (clues).
  final bool small;

  /// No cell drawn (outside the grid, e.g. nonogram clue corner).
  final bool hidden;
}

/// A board state in a demo: cells by index, where the finger is, and an optional caption.
class DemoFrame {
  const DemoFrame(this.cells, {this.finger, this.caption});

  final Map<int, DemoCell> cells;
  final int? finger;
  final String? caption;

  /// A new frame from this one with some cells changed.
  DemoFrame next(Map<int, DemoCell> changes, {int? finger, String? caption}) =>
      DemoFrame({...cells, ...changes}, finger: finger, caption: caption ?? this.caption);
}

/// Loops through [frames] on a small grid with an animated finger: the "GIF" of a how-to-play step,
/// drawn live so it stays sharp and matches the app's colors.
class GridDemo extends StatefulWidget {
  const GridDemo({super.key, required this.columns, required this.rows, required this.frames, this.frameMs = 900});

  final int columns;
  final int rows;
  final List<DemoFrame> frames;
  final int frameMs;

  @override
  State<GridDemo> createState() => _GridDemoState();
}

class _GridDemoState extends State<GridDemo> {
  late final Timer _timer;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: widget.frameMs), (_) {
      if (mounted) setState(() => _index = (_index + 1) % widget.frames.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.frames[_index];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      LayoutBuilder(builder: (context, constraints) {
        const gap = 4.0;
        final size = ((constraints.maxWidth.clamp(0, 300) - gap * (widget.columns - 1)) / widget.columns).clamp(18.0, 54.0);
        final width = size * widget.columns + gap * (widget.columns - 1);
        final height = size * widget.rows + gap * (widget.rows - 1);
        Offset centerOf(int i) => Offset((i % widget.columns) * (size + gap) + size / 2, (i ~/ widget.columns) * (size + gap) + size / 2);
        return SizedBox(
          width: width,
          height: height,
          child: Stack(clipBehavior: Clip.none, children: [
            for (var i = 0; i < widget.columns * widget.rows; i++)
              Positioned(
                left: centerOf(i).dx - size / 2,
                top: centerOf(i).dy - size / 2,
                width: size,
                height: size,
                child: _Cell(cell: frame.cells[i], size: size),
              ),
            if (frame.finger != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOut,
                left: centerOf(frame.finger!).dx - 6,
                top: centerOf(frame.finger!).dy - 4,
                child: const IgnorePointer(
                  // No icon shadow (Impeller can paint it far from the glyph).
                  child: Icon(Icons.touch_app_rounded, size: 34, color: AppColors.ink),
                ),
              ),
          ]),
        );
      }),
      const SizedBox(height: 10),
      SizedBox(
        height: 40,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            frame.caption ?? '',
            key: ValueKey(frame.caption),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.violet),
          ),
        ),
      ),
    ]);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell, required this.size});

  final DemoCell? cell;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = cell;
    if (c != null && c.hidden) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      decoration: BoxDecoration(
        color: c?.fill ?? Colors.white,
        shape: c?.round == true ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: c?.round == true ? null : BorderRadius.circular(size * 0.22),
        border: c?.fill == null ? Border.all(color: AppColors.line, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        c?.text ?? '',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.display,
          fontWeight: FontWeight.w700,
          fontSize: size * (c?.small == true ? 0.3 : 0.5),
          height: 1,
          color: c?.textColor ?? AppColors.ink,
        ),
      ),
    );
  }
}
