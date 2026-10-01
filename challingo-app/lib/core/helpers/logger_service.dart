import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../../di.dart';

class LoggerService {
  final Level logLevel;

  LoggerService({this.logLevel = Level.all}) {
    _logger = Logger(level: logLevel, printer: SimplePrinter());
  }

  late final Logger _logger;

  void d(Object message) => _logger.d(message);

  void i(Object message) => _logger.i(message);

  void w(Object message) => _logger.w(message);

  void e(Object message, [Object? error, StackTrace? stackTrace]) {
    // Log message only by default so decode errors don't repeat raw FormatException text.
    if (error == null && stackTrace == null) {
      _logger.e(message);
      return;
    }
    _logger.e(message, error: error, stackTrace: stackTrace);
    final trace = stackTrace ?? (error is Error ? error.stackTrace : null);
    if (trace != null) {
      debugPrint('══╡ $message ╞══');
      debugPrint(trace.toString());
      debugPrintStack(stackTrace: trace, label: message.toString());
    }
  }
}

mixin LoggerServiceHelperMixin {
  LoggerService get log => appLog;

  @protected
  void logD(String msg) => appLog.d('[$runtimeType] $msg');

  @protected
  void logI(String msg) => appLog.i('[$runtimeType] $msg');

  @protected
  void logW(String msg) => appLog.w('[$runtimeType] $msg');

  @protected
  void logE(String msg, [Object? e, StackTrace? st]) => appLog.e('[$runtimeType] $msg', e, st);
}

final appLog = locator<LoggerService>();
