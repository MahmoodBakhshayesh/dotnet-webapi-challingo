import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../board_context.dart';
import 'board_widgets.dart';

class WordGuessBoard extends StatefulWidget {
  const WordGuessBoard(this.board, {super.key});

  final BoardContext board;

  @override
  State<WordGuessBoard> createState() => _WordGuessBoardState();
}

class _WordGuessBoardState extends BoardState<WordGuessBoard> {
  @override
  BoardContext get board => widget.board;

  late final int length = (board.puzzle['length'] as num).toInt();
  late final int maxGuesses = (board.puzzle['maxGuesses'] as num).toInt();
  final List<(String, List<String>)> guesses = [];
  String typing = '';
  bool over = false;

  @override
  void initState() {
    super.initState();
    for (final g in ((board.savedState?['guesses'] ?? const []) as List).cast<Map>()) {
      guesses.add((g['guess'] as String, (g['marks'] as List).cast<String>()));
    }
  }

  /// Best mark seen per letter, for the keyboard.
  Map<String, String> get keyMarks {
    const rank = {'absent': 0, 'present': 1, 'correct': 2};
    final out = <String, String>{};
    for (final (word, marks) in guesses) {
      for (var i = 0; i < word.length; i++) {
        final prev = out[word[i]];
        if (prev == null || rank[marks[i]]! > rank[prev]!) out[word[i]] = marks[i];
      }
    }
    return out;
  }

  Future<void> enter() async {
    if (typing.length != length) {
      board.notify('Not enough letters.');
      return;
    }
    final word = typing;
    final result = await send(() => board.move({'guess': word}));
    if (result == null || !mounted) return;
    setState(() {
      guesses.add((word, (result.response['marks'] as List).cast<String>()));
      typing = '';
      over = result.response['answer'] != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: length / maxGuesses,
            child: Column(children: [
              for (var row = 0; row < maxGuesses; row++)
                Expanded(child: Row(children: [for (var i = 0; i < length; i++) Expanded(child: _tile(row, i))])),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 12),
      LetterKeyboard(
        enabled: !busy && !over,
        marks: keyMarks,
        onLetter: (c) => typing.length < length ? setState(() => typing += c) : null,
        onBackspace: () => typing.isEmpty ? null : setState(() => typing = typing.substring(0, typing.length - 1)),
        onEnter: enter,
      ),
    ]);
  }

  Widget _tile(int row, int i) {
    String letter = '';
    String? mark;
    if (row < guesses.length) {
      letter = guesses[row].$1[i];
      mark = guesses[row].$2[i];
    } else if (row == guesses.length && i < typing.length) {
      letter = typing[i];
    }
    final bg = switch (mark) {
      'correct' => AppColors.mint,
      'present' => AppColors.sun,
      'absent' => AppColors.inkMuted,
      _ => Colors.white,
    };
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: mark == null ? Border.all(color: letter.isEmpty ? AppColors.line : AppColors.ink, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          letter.toUpperCase(),
          style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 28, color: mark == null || mark == 'present' ? AppColors.ink : Colors.white),
        ),
      ),
    );
  }
}
