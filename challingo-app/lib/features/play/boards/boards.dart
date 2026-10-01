import 'package:flutter/widgets.dart';

import '../board_context.dart';
import '../game_catalog.dart';
import 'code_breaker_board.dart';
import 'kakuro_board.dart';
import 'mine_logic_board.dart';
import 'mini_crossword_board.dart';
import 'nonogram_board.dart';
import 'number_merge_board.dart';
import 'path_link_board.dart';
import 'sudoku_board.dart';
import 'word_guess_board.dart';
import 'word_hunt_board.dart';

/// The board widget for a game.
Widget buildBoard(GameKind game, BoardContext board) => switch (game) {
  GameKind.sudoku => SudokuBoard(board),
  GameKind.kakuro => KakuroBoard(board),
  GameKind.nonogram => NonogramBoard(board),
  GameKind.pathLink => PathLinkBoard(board),
  GameKind.mineLogic => MineLogicBoard(board),
  GameKind.codeBreaker => CodeBreakerBoard(board),
  GameKind.wordGuess => WordGuessBoard(board),
  GameKind.wordHunt => WordHuntBoard(board),
  GameKind.miniCrossword => MiniCrosswordBoard(board),
  GameKind.numberMerge => NumberMergeBoard(board),
};
