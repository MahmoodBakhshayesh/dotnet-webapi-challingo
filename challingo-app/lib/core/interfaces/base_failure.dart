import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helpers/failure_logger.dart';
import '../helpers/network_exception.dart';
import 'base_result.dart';

enum FailureSeverity { info, warning, error, critical }

class FailureNotice {
  final Failure failure;
  final FailureSeverity severity;
  final VoidCallback? retry;
  final Object? extra; // optional payload

  const FailureNotice({
    required this.failure,
    this.severity = FailureSeverity.error,
    this.retry,
    this.extra,
  });

  factory FailureNotice.fromNetworkException(NetworkException networkException) => FailureNotice(
    failure: NetworkFailure(networkException.message, code: networkException.statusCode, response: networkException.data),
  );

  @override
  String toString() {
    return failure.message;
  }
}

class FailureBus {
  FailureBus._();

  static final FailureBus I = FailureBus._();

  /// Async broadcast — avoids re-entrant [add] while a listener is still handling an event.
  final _ctrl = StreamController<FailureNotice>.broadcast();

  Stream<FailureNotice> get stream => _ctrl.stream;

  static bool _shouldIgnoreMessage(String message) {
    return message.contains('visitChildElements() called during build') ||
        message.contains('Cannot fire new event') ||
        message.contains('Controller is already firing an event');
  }

  void emit(FailureNotice n) {
    if (_shouldIgnoreMessage(n.failure.message)) return;
    FailureLogger.logNotice(n);
    _enqueue(n);
  }

  void emitMsg(String n) {
    if (_shouldIgnoreMessage(n)) return;
    final notice = FailureNotice(failure: ServerFailure(n));
    FailureLogger.logNotice(notice);
    _enqueue(notice);
  }

  void _enqueue(FailureNotice n) {
    if (_ctrl.isClosed) return;
    scheduleMicrotask(() {
      if (_ctrl.isClosed) return;
      _ctrl.add(n);
    });
  }

  void dispose() => _ctrl.close();
}
