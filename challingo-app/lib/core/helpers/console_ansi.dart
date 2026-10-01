/// ANSI colors for debug console output (VS Code / Cursor / terminal).
abstract class ConsoleAnsi {
  static const redCode = '\x1B[31m';
  static const yellowCode = '\x1B[33m';
  static const reset = '\x1B[0m';

  static String red(String text) => '$redCode$text$reset';

  static String yellow(String text) => '$yellowCode$text$reset';
}
