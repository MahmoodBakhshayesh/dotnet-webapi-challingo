import 'package:challingo/features/play/boards/number_merge_board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mulberry32 matches the JavaScript/C# reference values', () {
    final rng = Mulberry32(1);
    expect([rng.next(), rng.next(), rng.next()], [2693262067, 11749833, 2265367787]);
  });

  test('a corner strategy reaches 128 and only counts moves that change the board', () {
    final board = MergeBoard(4, 123456789);
    final moves = StringBuffer();
    for (var i = 0; i < 4000 && board.maxTile < 128; i++) {
      for (final m in ['D', 'L', 'R', 'U']) {
        if (board.move(m)) {
          moves.write(m);
          break;
        }
      }
    }
    expect(board.maxTile, greaterThanOrEqualTo(128));
    // Replaying the same moves from the same seed lands on the same board.
    final replay = MergeBoard(4, 123456789);
    for (final m in moves.toString().split('')) {
      replay.move(m);
    }
    expect(replay.cells, board.cells);
  });
}
