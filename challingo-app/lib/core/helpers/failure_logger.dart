import 'package:flutter/foundation.dart';

import '../helpers/console_ansi.dart';
import '../helpers/decode_stack_trace.dart';
import '../helpers/repository_caught_error.dart';
import '../interfaces/base_result.dart';
import '../interfaces/base_failure.dart';

/// Logs failures to the debug console. Decode errors show only the entity [fromJson] site.
abstract class FailureLogger {
  static void logFailure(
    Failure failure, {
    bool muted = false,
    String? source,
  }) {
    _printLines(
      _formatLine(failure, muted: muted, source: source),
      useRed: true,
    );

    if (failure is NetworkFailure) {
      if (failure.response != null) {
        debugPrint(ConsoleAnsi.red('NetworkFailure response: ${failure.response}'));
      }
      if (failure.url != null) {
        debugPrint(
          ConsoleAnsi.red(
            'NetworkFailure ${failure.method ?? ''} ${failure.url} code=${failure.code}',
          ),
        );
      }
    }
  }

  static void logNotice(FailureNotice notice, {bool muted = false}) {
    logFailure(notice.failure, muted: muted);
  }

  static void _printLines(String text, {required bool useRed}) {
    for (final row in text.split('\n')) {
      debugPrint(useRed ? ConsoleAnsi.red(row) : row);
    }
  }

  static String _formatLine(
    Failure failure, {
    required bool muted,
    String? source,
  }) {
    final tag = muted ? '[muted failure]' : '[failure]';
    final src = source != null ? ' ($source)' : '';
    final prefix = '$tag$src ${failure.runtimeType}:';

    final message = failure.message.trim();
    if (message.contains('\n  at ')) {
      return '$prefix $message';
    }

    final stack = failure.stackTrace ?? unwrapRepositoryStackTrace(failure.cause);
    final origin = DecodeStackTrace.primaryOrigin(stack);
    if (origin != null) {
      return '$prefix $message\n  ${origin.atLine}';
    }

    return '$prefix $message';
  }
}
