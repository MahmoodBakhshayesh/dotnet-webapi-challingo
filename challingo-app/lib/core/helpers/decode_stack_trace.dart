/// Picks the most useful stack frame for API / JSON decode failures.
class DecodeStackFrame {
  final String symbol;
  final String location;

  const DecodeStackFrame({required this.symbol, required this.location});

  /// e.g. `at Post.fromJson (package:challingo/.../post_class.dart:84:17)`
  String get atLine {
    final name = symbol.replaceFirst(RegExp(r'^new\s+'), '');
    return 'at $name ($location)';
  }

  String get shortFile {
    final match = RegExp(r'/([^/]+\.dart):\d+').firstMatch(location);
    return match?.group(1) ?? location;
  }

  int? get line {
    final match = RegExp(r':(\d+):\d+\)?$').firstMatch(location);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
}

abstract class DecodeStackTrace {
  static final _framePattern = RegExp(r'^\s*#\d+\s+(.+?)\s+\(([^)]+)\)\s*$');

  /// First meaningful decode site — usually `SomeEntity.fromJson` in `domain/entities`.
  static DecodeStackFrame? primaryOrigin(StackTrace? stackTrace) {
    if (stackTrace == null) return null;

    DecodeStackFrame? firstAppFrame;

    for (final raw in stackTrace.toString().split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final match = _framePattern.firstMatch(line);
      if (match == null) continue;

      final symbol = match.group(1)!.trim();
      final location = match.group(2)!.trim();

      if (_isNoise(symbol, location)) continue;

      final frame = DecodeStackFrame(symbol: symbol, location: location);

      if (_isEntityFromJson(symbol, location)) {
        return frame;
      }

      firstAppFrame ??= _isProjectLib(location) ? frame : null;
    }

    return firstAppFrame;
  }

  static bool _isNoise(String symbol, String location) {
    if (location.startsWith('dart:')) return true;
    if (location.contains('json_validators.dart')) return true;
    if (symbol.contains('throwTypeError')) return true;
    if (symbol.startsWith('expect')) return true;
    if (location.contains('remote_response_parser.dart')) return true;
    if (location.contains('use_case_response_mapper.dart')) return true;
    if (location.contains('iterable.dart')) return true;
    if (location.contains('growable_array.dart')) return true;
    if (location.contains('array_patch.dart')) return true;
    return false;
  }

  static bool _isEntityFromJson(String symbol, String location) {
    if (!symbol.contains('fromJson')) return false;
    return location.contains('/entities/') || location.contains('/domain/');
  }

  static bool _isProjectLib(String location) {
    return location.contains('package:challingo/');
  }
}
