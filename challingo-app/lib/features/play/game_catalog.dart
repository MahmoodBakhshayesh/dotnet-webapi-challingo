import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Every game the API offers, keyed like the server (`IPuzzleGame.Key`).
enum GameKind {
  wordHunt('word-hunt', 'Word Hunt', 'Swipe letters to find words before time runs out'),
  wordGuess('word-guess', 'Word Guess', 'Find the hidden five-letter word in six tries'),
  miniCrossword('mini-crossword', 'Mini Crossword', 'A small crossword with short clues'),
  pathLink('path-link', 'Path Link', 'Join matching dots and fill the whole board'),
  sudoku('sudoku', 'Sudoku', 'Every row, column and box holds each number once'),
  kakuro('kakuro', 'Kakuro', 'Fill runs with digits that add up to their clues'),
  nonogram('nonogram', 'Nonogram', 'Shade cells to match the row and column clues'),
  mineLogic('mine-logic', 'Mine Logic', 'Clear every safe cell — no guessing needed'),
  codeBreaker('code-breaker', 'Code Breaker', 'Crack the hidden colour code'),
  numberMerge('number-merge', 'Number Merge', 'Slide and merge tiles to reach the target');

  const GameKind(this.key, this.title, this.tagline);

  final String key;
  final String title;
  final String tagline;

  static GameKind? fromKey(String key) => values.where((g) => g.key == key).firstOrNull;
}

/// The game's line icon from the visual identity canvas.
class GameGlyph extends StatelessWidget {
  const GameGlyph(this.game, {super.key, this.size = 26, this.color = AppColors.ink});

  final GameKind game;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GlyphPainter(game, color));
}

/// A glyph inside the rounded tinted tile used on cards.
class GameGlyphTile extends StatelessWidget {
  const GameGlyphTile(this.game, {super.key, this.size = 48, this.background = AppColors.lilac, this.glyphColor = AppColors.ink});

  final GameKind game;
  final double size;
  final Color background;
  final Color glyphColor;

  GameGlyphTile withGlyphColor(Color color) => GameGlyphTile(game, size: size, background: background, glyphColor: color);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * 0.3)),
    alignment: Alignment.center,
    child: GameGlyph(game, size: size * 0.55, color: glyphColor),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.game, this.color);

  final GameKind game;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    RRect box(double l, double t, double w, double h, double r) => RRect.fromLTRBR(l, t, l + w, t + h, Radius.circular(r));

    switch (game) {
      case GameKind.wordHunt:
        canvas.drawRRect(box(3, 3, 18, 18, 4), stroke);
        canvas.drawPath(Path()..moveTo(8, 8)..lineTo(12, 12)..lineTo(16, 12)..lineTo(16, 16), stroke);
      case GameKind.wordGuess:
        for (final x in [1.5, 6.0, 10.5, 15.0, 19.5]) {
          canvas.drawRRect(box(x, 9, 3.4, 6, 1), stroke);
        }
      case GameKind.miniCrossword:
        canvas.drawPath(
          Path()
            ..moveTo(9, 3)..lineTo(15, 3)..lineTo(15, 9)..lineTo(21, 9)..lineTo(21, 15)..lineTo(15, 15)
            ..lineTo(15, 21)..lineTo(9, 21)..lineTo(9, 15)..lineTo(3, 15)..lineTo(3, 9)..lineTo(9, 9)..close(),
          stroke,
        );
      case GameKind.pathLink:
        canvas.drawCircle(const Offset(6, 6), 2.5, stroke);
        canvas.drawCircle(const Offset(18, 18), 2.5, stroke);
        canvas.drawPath(Path()..moveTo(8.5, 6)..lineTo(14, 6)..arcToPoint(const Offset(18, 10), radius: const Radius.circular(4))..lineTo(18, 15.5), stroke);
      case GameKind.sudoku:
        canvas.drawRRect(box(3, 3, 18, 18, 3), stroke);
        for (final v in [9.0, 15.0]) {
          canvas.drawLine(Offset(v, 3), Offset(v, 21), stroke);
          canvas.drawLine(Offset(3, v), Offset(21, v), stroke);
        }
      case GameKind.kakuro:
        canvas.drawRRect(box(3, 3, 18, 18, 3), stroke);
        canvas.drawLine(const Offset(3, 3), const Offset(21, 21), stroke);
        canvas.drawLine(const Offset(12, 3), const Offset(12, 21), stroke);
      case GameKind.nonogram:
        canvas.drawRRect(box(3, 3, 18, 18, 3), stroke);
        for (final (x, y) in [(7.0, 7.0), (13.0, 13.0), (7.0, 13.0)]) {
          canvas.drawRect(Rect.fromLTWH(x, y, 4, 4), fill);
        }
      case GameKind.mineLogic:
        canvas.drawLine(const Offset(6, 21), const Offset(6, 4), stroke);
        canvas.drawPath(Path()..moveTo(6, 4)..lineTo(17, 4)..lineTo(14, 8)..lineTo(17, 12)..lineTo(6, 12), stroke);
      case GameKind.codeBreaker:
        for (final x in [4.5, 9.5, 14.5, 19.5]) {
          canvas.drawCircle(Offset(x, 12), 2.5, stroke);
        }
      case GameKind.numberMerge:
        canvas.drawRRect(box(2.5, 7, 8, 10, 2), stroke);
        canvas.drawRRect(box(13.5, 7, 8, 10, 2), stroke);
        canvas.drawLine(const Offset(10.5, 12), const Offset(13.5, 12), stroke);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.game != game || old.color != color;
}
