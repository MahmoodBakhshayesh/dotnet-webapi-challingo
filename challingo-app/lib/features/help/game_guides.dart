import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../play/game_catalog.dart';
import '../play/boards/path_link_board.dart' show PathLinkPalette;
import 'grid_demo.dart';

/// One page of a how-to-play guide: text plus an optional looping demo.
class GuideStep {
  const GuideStep(this.title, this.body, {this.columns = 0, this.rows = 0, this.frames = const [], this.frameMs = 900});

  final String title;
  final String body;
  final int columns;
  final int rows;
  final List<DemoFrame> frames;
  final int frameMs;
}

class GameGuide {
  const GameGuide({required this.goal, required this.steps, required this.scoring});

  final String goal;
  final List<GuideStep> steps;

  /// How ranked runs are ordered.
  final String scoring;
}

// --- tiny helpers -----------------------------------------------------------------------------

DemoCell _given(String t) => DemoCell(t, fill: AppColors.line);
DemoCell _entered(String t) => DemoCell(t, textColor: AppColors.violet);
DemoCell _active(String t) => DemoCell(t, fill: AppColors.lilac, textColor: AppColors.violet);
DemoCell _picked(String t) => DemoCell(t, fill: AppColors.violet, textColor: Colors.white);
DemoCell _ink(String t, {bool small = false}) => DemoCell(t, fill: AppColors.ink, textColor: Colors.white, small: small);
DemoCell _mark(String t, String mark) => switch (mark) {
  'c' => DemoCell(t, fill: AppColors.mint, textColor: Colors.white),
  'p' => DemoCell(t, fill: AppColors.sun),
  _ => DemoCell(t, fill: AppColors.inkMuted, textColor: Colors.white),
};

/// Letters laid out from a string (one char per cell, '#' = block, ' ' = empty).
Map<int, DemoCell> _letters(String grid, {DemoCell Function(String)? style}) => {
  for (var i = 0; i < grid.length; i++)
    if (grid[i] == '#') i: _ink('') else if (grid[i] != ' ') i: (style ?? DemoCell.new)(grid[i]),
};

List<DemoFrame> _typeRow(DemoFrame start, int row, String word, String marks, String caption, {int columns = 5}) {
  final frames = <DemoFrame>[];
  var f = start;
  for (var i = 0; i < word.length; i++) {
    f = f.next({row * columns + i: DemoCell(word[i])}, caption: 'Type a word');
    frames.add(f);
  }
  f = f.next({for (var i = 0; i < word.length; i++) row * columns + i: _mark(word[i], marks[i])}, caption: caption);
  frames.add(f);
  return frames;
}

// --- guides -----------------------------------------------------------------------------------

GameGuide guideFor(GameKind game) => switch (game) {
  GameKind.sudoku => _sudoku(),
  GameKind.pathLink => _pathLink(),
  GameKind.wordHunt => _wordHunt(),
  GameKind.wordGuess => _wordGuess(),
  GameKind.miniCrossword => _crossword(),
  GameKind.kakuro => _kakuro(),
  GameKind.nonogram => _nonogram(),
  GameKind.mineLogic => _mineLogic(),
  GameKind.codeBreaker => _codeBreaker(),
  GameKind.numberMerge => _numberMerge(),
};

GameGuide _sudoku() {
  // 4×4 example; real boards are 6×6 (Beginner) or 9×9.
  final base = DemoFrame({
    0: _given('1'), 1: _given('2'), 3: _given('4'),
    4: _given('3'), 5: _given('4'), 6: _given('1'),
    8: _given('2'), 10: _given('4'), 11: _given('3'),
    12: _given('4'), 13: _given('3'), 15: _given('1'),
  }, caption: 'Each row, column and box: 1–4 once');
  final f1 = base.next({2: _active('')}, finger: 2, caption: 'Tap an empty cell');
  final f2 = f1.next({2: _entered('3')}, caption: 'Row 1 is missing a 3');
  final f3 = f2.next({7: _active('')}, finger: 7, caption: 'Row 2 is missing a 2');
  final f4 = f3.next({7: _entered('2')});
  final f5 = f4.next({9: _entered('1')}, finger: 9, caption: 'Column 2 is missing a 1');
  final f6 = f5.next({14: _entered('2')}, finger: 14, caption: 'Full and correct — solved!');
  return GameGuide(
    goal: 'Fill the grid so every row, column and box holds each number exactly once.',
    steps: [
      GuideStep('Place numbers', 'Tap a cell, then a number. Grey numbers are given and can’t change. Beginner is 6×6; higher levels are 9×9.',
          columns: 4, rows: 4, frames: [base, f1, f2, f3, f4, f5, f6, f6]),
      const GuideStep('Erase and submit', 'Erase clears the selected cell. Numbers that clash in a row, column or box turn red. Submit unlocks once the grid is full with no clashes.'),
    ],
    scoring: 'Ranked runs: the fastest correct solve ranks first.',
  );
}

GameGuide _pathLink() {
  final c = PathLinkPalette.colors;
  DemoCell dot(int i) => DemoCell('', fill: c[i], round: true);
  DemoCell path(int i) => DemoCell('', fill: c[i].withValues(alpha: 0.35));
  // Paths: violet 0→1→2→3→7, coral 4→8→12→13, gold 11→15→14, mint 5→6→10→9.
  final base = DemoFrame({0: dot(0), 7: dot(0), 4: dot(1), 13: dot(1), 11: dot(2), 14: dot(2), 5: dot(3), 9: dot(3)},
      caption: 'Join each pair of matching dots');
  final frames = <DemoFrame>[base];
  var f = base.next({}, finger: 0, caption: 'Drag from a dot…');
  frames.add(f);
  for (final i in [1, 2, 3]) {
    f = f.next({i: path(0)}, finger: i);
    frames.add(f);
  }
  f = f.next({}, finger: 7, caption: '…to its twin');
  frames.add(f);
  f = f.next({8: path(1), 12: path(1), 15: path(2), 6: path(3), 10: path(3)}, finger: 13, caption: 'Fill every cell — no crossing');
  frames.addAll([f, f]);
  return GameGuide(
    goal: 'Connect every pair of matching dots with a path, and fill the whole board.',
    steps: [
      GuideStep('Draw paths', 'Drag from a dot through neighbouring cells (no diagonals) to the dot of the same color. Paths can’t cross, and every cell must be used.',
          columns: 4, rows: 4, frames: frames, frameMs: 700),
      const GuideStep('Fix mistakes', 'Drag from a dot again to redraw its path, or from the middle of a path to cut it there and carry on. Boards grow from 5×5 (Beginner) to 8×8 (Expert).'),
    ],
    scoring: 'Ranked runs: the fastest full board ranks first.',
  );
}

GameGuide _wordHunt() {
  final base = DemoFrame(_letters('CATSOREDPLANEMIT'), caption: 'Swipe across touching letters');
  final frames = <DemoFrame>[base];
  var f = base;
  var word = '';
  for (final i in [0, 1, 5, 6]) {
    word += 'CATSOREDPLANEMIT'[i];
    f = f.next({i: _picked('CATSOREDPLANEMIT'[i])}, finger: i, caption: word);
    frames.add(f);
  }
  f = DemoFrame(base.cells, finger: 6, caption: 'CARE  +1');
  frames.add(f);
  word = '';
  for (final i in [8, 9, 10, 11, 15]) {
    word += 'CATSOREDPLANEMIT'[i];
    f = f.next({i: _picked('CATSOREDPLANEMIT'[i])}, finger: i, caption: word);
    frames.add(f);
  }
  frames.add(DemoFrame(base.cells, finger: 15, caption: 'PLANT  +2'));
  return GameGuide(
    goal: 'Find as many words as you can in 2½ minutes.',
    steps: [
      GuideStep('Swipe words', 'Slide your finger over neighbouring letters, diagonals included. Each letter tile once per word. Lift your finger to submit.',
          columns: 4, rows: 4, frames: frames, frameMs: 650),
      const GuideStep('Longer is better', '3–4 letters: 1 point · 5: 2 · 6: 3 · 7: 5 · 8 or more: 11. Each word counts once. “Qu” is one tile. Higher levels use a 5×5 board and 4-letter minimum.'),
    ],
    scoring: 'Ranked runs: most points wins; earlier finish breaks ties.',
  );
}

GameGuide _wordGuess() {
  const empty = DemoFrame({}, caption: 'Guess the hidden word');
  final frames = <DemoFrame>[empty];
  frames.addAll(_typeRow(empty, 0, 'TAPIR', 'ppp--', 'Yellow: in the word, wrong spot'));
  frames.addAll(_typeRow(frames.last, 1, 'CRANE', '--cc-', 'Green: right letter, right spot'));
  frames.addAll(_typeRow(frames.last, 2, 'PLANT', 'ccccc', 'All green — solved in 3!'));
  frames.add(frames.last);
  return GameGuide(
    goal: 'Find the hidden five-letter word in six guesses.',
    steps: [
      GuideStep('Read the colors', 'Type any real five-letter word and press Enter. Green = right spot, yellow = in the word but elsewhere, grey = not in the word.',
          columns: 5, rows: 3, frames: frames, frameMs: 550),
    ],
    scoring: 'Ranked runs: fewest guesses first, then fastest.',
  );
}

GameGuide _crossword() {
  final base = DemoFrame(_letters('    #    '), caption: 'Tap a square');
  // Grid: B A T / A # O / D O E
  final across = base.next({0: _active(''), 1: _active(''), 2: _active('')}, finger: 0, caption: '1 Across: flying mammal');
  final a1 = across.next({0: _active('B'), 1: _active('A'), 2: _active('T')});
  final down = a1.next({0: _active('B'), 1: _entered('A'), 2: _entered('T'), 3: _active(''), 6: _active('')}, finger: 0, caption: 'Tap again: 1 Down — not good');
  final d1 = down.next({3: _active('A'), 6: _active('D')});
  final d3 = d1.next({0: _entered('B'), 3: _entered('A'), 6: _entered('D'), 2: _active('T'), 5: _active(''), 8: _active('')}, finger: 5, caption: '2 Down: part of a foot');
  final done = d3.next({2: _entered('T'), 5: _entered('O'), 8: _entered('E'), 7: _entered('O')}, caption: 'Every square filled — solved!');
  return GameGuide(
    goal: 'Fill the small grid so every Across and Down answer matches its clue.',
    steps: [
      GuideStep('Across and down', 'Tap a square to pick a word; tap the same square again to switch between Across and Down. The clue shows above the keyboard.',
          columns: 3, rows: 3, frames: [base, across, a1, down, d1, d3, done, done], frameMs: 1000),
    ],
    scoring: 'Ranked runs: the fastest correct grid ranks first.',
  );
}

GameGuide _kakuro() {
  // Clues: column sums 4↓ and 6↓, row sums →3 and →7. Answer 1 2 / 3 4.
  final base = DemoFrame({
    0: _ink(''), 1: _ink('4↓', small: true), 2: _ink('6↓', small: true),
    3: _ink('→3', small: true), 6: _ink('→7', small: true),
  }, caption: 'Each run adds up to its clue');
  final f1 = base.next({4: _entered('1')}, finger: 4, caption: '→3: 1 + 2');
  final f2 = f1.next({5: _entered('2')}, finger: 5);
  final f3 = f2.next({7: _entered('3')}, finger: 7, caption: '4↓: 1 + 3');
  final f4 = f3.next({8: _entered('4')}, finger: 8, caption: '6↓: 2 + 4 · →7: 3 + 4 ✓');
  return GameGuide(
    goal: 'Fill the white cells with 1–9 so each row and column run adds up to its clue.',
    steps: [
      GuideStep('Make the sums', 'A clue with ↓ is the total of the cells below it; → is the total of the cells to its right. No number repeats inside one run.',
          columns: 3, rows: 3, frames: [base, f1, f2, f3, f4, f4], frameMs: 1100),
      const GuideStep('Tip', 'Small sums have few options: two cells adding to 3 must be 1 and 2, and 17 must be 8 and 9. Start there.'),
    ],
    scoring: 'Ranked runs: the fastest correct grid ranks first.',
  );
}

GameGuide _nonogram() {
  // 5×5 demo: clue row on top, clue column on the left, 4×4 picture.
  DemoCell clue(String t) => DemoCell(t, small: true, fill: AppColors.cloud);
  DemoCell fill() => const DemoCell('', fill: AppColors.ink);
  final base = DemoFrame({
    0: const DemoCell('', hidden: true),
    1: clue('1 2'), 2: clue('3'), 3: clue('2'), 4: clue('1 2'),
    5: clue('2 1'), 10: clue('2'), 15: clue('4'), 20: clue('1 1'),
  }, caption: 'Numbers = runs of filled cells');
  final f1 = base.next({16: fill(), 17: fill(), 18: fill(), 19: fill()}, finger: 17, caption: 'Row “4”: fill all four');
  final f2 = f1.next({6: fill(), 7: fill(), 9: fill()}, finger: 6, caption: '“2 1”: two, a gap, then one');
  final f3 = f2.next({12: fill(), 13: fill()}, finger: 12, caption: '“2”: two together');
  final f4 = f3.next({21: fill(), 24: fill()}, finger: 24, caption: 'Every clue matches — solved!');
  return GameGuide(
    goal: 'Shade cells so each row and column matches its number clues, revealing a picture.',
    steps: [
      GuideStep('Read the clues', '“2 1” means a run of 2 filled cells, at least one gap, then a run of 1, in that order. Tap to fill, tap again to clear.',
          columns: 5, rows: 5, frames: [base, f1, f2, f3, f4, f4], frameMs: 1100),
    ],
    scoring: 'Ranked runs: the fastest correct picture ranks first.',
  );
}

GameGuide _mineLogic() {
  const hidden = DemoCell('', fill: AppColors.lilac);
  DemoCell open(String n) => DemoCell(n == '0' ? '' : n, fill: AppColors.cloud, textColor: AppColors.violet);
  const flag = DemoCell('⚑', fill: AppColors.coral, textColor: Colors.white);
  // Mines at 3 and 12.
  const numbers = ['0', '0', '1', 'M', '0', '0', '1', '1', '1', '1', '0', '0', 'M', '1', '0', '0'];
  final base = DemoFrame({for (var i = 0; i < 16; i++) i: hidden}, caption: 'Tap a cell to reveal it');
  final f1 = base.next({for (var i = 0; i < 16; i++) if (numbers[i] != 'M') i: open(numbers[i])}, finger: 5,
      caption: 'A number = mines touching it');
  final f2 = f1.next({3: flag}, finger: 3, caption: 'That 1 can only mean here: flag it');
  final f3 = f2.next({12: flag}, finger: 12, caption: 'All safe cells open — solved!');
  return GameGuide(
    goal: 'Open every safe cell without touching a mine. Every board can be solved by logic alone.',
    steps: [
      GuideStep('Reveal and reason', 'Tap to open a cell. A number tells how many of its 8 neighbours hide a mine. Long-press to place a flag where you know a mine is.',
          columns: 4, rows: 4, frames: [base, f1, f2, f3, f3], frameMs: 1200),
      const GuideStep('Careful', 'Opening a mine ends the run. Bigger boards with more mines come at higher levels.'),
    ],
    scoring: 'Ranked runs: the fastest clear board ranks first.',
  );
}

GameGuide _codeBreaker() {
  final c = PathLinkPalette.colors;
  DemoCell peg(int i) => DemoCell('', fill: c[i], round: true);
  const empty = DemoFrame({}, caption: 'Guess the hidden color code');
  // Secret: colors 0, 1, 2, 3.
  final g1 = <DemoFrame>[];
  var f = empty;
  for (final (i, color) in [(0, 0), (1, 2), (2, 1), (3, 4)]) {
    f = f.next({i: peg(color)}, finger: i, caption: 'Pick a color for each spot');
    g1.add(f);
  }
  final r1 = f.next({}, caption: '1 right place · 2 wrong place');
  final g2 = <DemoFrame>[];
  f = r1;
  for (final (i, color) in [(4, 0), (5, 1), (6, 2), (7, 3)]) {
    f = f.next({i: peg(color)}, finger: i, caption: 'Use the feedback');
    g2.add(f);
  }
  final r2 = f.next({}, caption: '4 right place — cracked!');
  return GameGuide(
    goal: 'Work out the secret color code in as few guesses as possible.',
    steps: [
      GuideStep('Guess and learn', 'Fill every spot and submit. Green count = right color in the right spot; yellow count = right color in the wrong spot. Colors can repeat.',
          columns: 4, rows: 2, frames: [empty, ...g1, r1, r1, ...g2, r2, r2], frameMs: 650),
    ],
    scoring: 'Ranked runs: fewest guesses first, then fastest.',
  );
}

GameGuide _numberMerge() {
  DemoCell tile(int v) => switch (v) {
    2 => const DemoCell('2', fill: AppColors.lilac, textColor: AppColors.violet),
    4 => const DemoCell('4', fill: AppColors.sun),
    _ => DemoCell('$v', fill: AppColors.coral, textColor: Colors.white),
  };
  final start = DemoFrame({0: tile(2), 1: tile(2), 5: tile(4), 7: tile(4)}, finger: 3, caption: 'Swipe to slide every tile');
  final swiping = start.next({}, finger: 0, caption: 'Swipe ←');
  final merged = DemoFrame({0: tile(4), 4: tile(8)}, finger: 0, caption: 'Equal tiles merge: 2+2, 4+4');
  final spawned = merged.next({10: tile(2)}, caption: 'A new tile appears after each move');
  return GameGuide(
    goal: 'Slide and merge tiles until you make the target tile (128 on Beginner, up to 1024 on Expert).',
    steps: [
      GuideStep('Slide and merge', 'Swipe up, down, left or right: all tiles slide that way and two equal tiles merge into their sum. Everyone in a run gets the same new tiles, so it’s pure skill.',
          columns: 4, rows: 4, frames: [start, swiping, merged, spawned, spawned], frameMs: 1100),
    ],
    scoring: 'Ranked runs: fewest moves first, then fastest.',
  );
}
