import 'package:challingo/core/helpers/decode_stack_trace.dart';
import 'package:challingo/core/helpers/network_exception.dart';

class ErrorMessageFormatter {
  static String format(Object error, [StackTrace? stackTrace]) {
    if (error is NetworkException) {
      return error.message;
    }

    final raw = error.toString().trim();
    final origin = DecodeStackTrace.primaryOrigin(stackTrace);

    final formatMatch = RegExp(r"Expected non-null ([^ ]+) for '([^']+)'").firstMatch(raw);
    if (formatMatch != null) {
      final expected = formatMatch.group(1)!;
      final field = formatMatch.group(2)!;
      return _withOrigin(
        origin,
        "Invalid API payload: field '$field' is missing/null, expected $expected.",
      );
    }

    final nullSubtypeMatch = RegExp(r"type 'Null' is not a subtype of type '([^']+)'").firstMatch(raw);
    if (nullSubtypeMatch != null) {
      final expected = nullSubtypeMatch.group(1)!;
      final fieldFromMessage =
          RegExp(r"\['([^']+)'\]").firstMatch(raw)?.group(1) ??
          RegExp(r'\["([^"]+)"\]').firstMatch(raw)?.group(1);
      if (fieldFromMessage != null) {
        return _withOrigin(
          origin,
          "Invalid API payload: field '$fieldFromMessage' is null/missing, expected $expected.",
        );
      }
      return _withOrigin(
        origin,
        'Invalid API payload: a required field is null/missing, expected $expected.',
      );
    }

    final base = raw.isEmpty ? 'Unknown error' : raw;
    return _withOrigin(origin, base);
  }

  static String _withOrigin(DecodeStackFrame? origin, String message) {
    if (origin == null) return message;
    return '$message\n  ${origin.atLine}';
  }
}
