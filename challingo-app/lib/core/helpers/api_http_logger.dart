import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/networking/network_log_level.dart';

/// Plain-text Dio logger (copy-friendly). Off by default; enable globally or per request.
class ApiHttpLogger extends Interceptor {
  ApiHttpLogger({this.defaultLevel = NetworkLogLevel.none});

  static const extraLogLevelKey = 'apiLogLevel';
  static const extraStartKey = '_apiHttpLogStart';

  final NetworkLogLevel defaultLevel;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[extraStartKey] = Stopwatch()..start();
    final level = _levelFor(options);
    if (level != NetworkLogLevel.none) {
      _logLine('--> ${options.method} ${_fullUri(options)}');
      if (level == NetworkLogLevel.full && options.data != null) {
        _logJsonBody(_formatBody(options.data));
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final level = _levelFor(response.requestOptions);
    if (level != NetworkLogLevel.none) {
      final ms = _elapsedMs(response.requestOptions);
      final status = response.statusCode ?? 0;
      final phrase = response.statusMessage ?? 'OK';
      _logLine(
        '<-- ${response.requestOptions.method} $status $phrase (${ms}ms) ${_fullUri(response.requestOptions)}',
      );
      if (level == NetworkLogLevel.full) {
        _logJsonBody(_formatBody(response.data));
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final level = _levelFor(err.requestOptions);
    if (level != NetworkLogLevel.none) {
      final ms = _elapsedMs(err.requestOptions);
      final status = err.response?.statusCode;
      final statusPart = status != null ? '$status ' : '';
      _logLine(
        '<-- ${err.requestOptions.method} ${statusPart}ERROR (${ms}ms) ${_fullUri(err.requestOptions)}',
      );
      if (level == NetworkLogLevel.full) {
        if (err.response?.data != null) {
          _logJsonBody(_formatBody(err.response!.data));
        }
        if (err.message != null) {
          _logLine(err.message!);
        }
      }
    }
    handler.next(err);
  }

  NetworkLogLevel _levelFor(RequestOptions options) {
    final value = options.extra[extraLogLevelKey];
    if (value is NetworkLogLevel) return value;
    return defaultLevel;
  }

  int _elapsedMs(RequestOptions options) {
    final sw = options.extra[extraStartKey];
    if (sw is Stopwatch) {
      return sw.elapsedMilliseconds;
    }
    return 0;
  }

  String _fullUri(RequestOptions options) {
    if (options.uri.toString().isNotEmpty) {
      return options.uri.toString();
    }
    return options.path;
  }

  static String _formatBody(dynamic data) {
    if (data == null) return '(empty)';
    try {
      if (data is Map || data is List) {
        return const JsonEncoder.withIndent('  ').convert(data);
      }
      if (data is String) {
        final trimmed = data.trim();
        if (trimmed.isEmpty) return '(empty)';
        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          return const JsonEncoder.withIndent('  ').convert(jsonDecode(trimmed));
        }
        return data;
      }
      if (data is FormData) {
        return 'FormData(fields: ${data.fields.length}, files: ${data.files.length})';
      }
    } catch (_) {
      return data.toString();
    }
    return data.toString();
  }

  /// Request/response summary (not JSON).
  static void _logLine(String line) => debugPrint(line);

  /// Body only — no prefix so the block can be copied as valid JSON.
  static void _logJsonBody(String content) {
    for (final line in content.split('\n')) {
      debugPrint(line);
    }
  }
}

/// Resolves per-request override vs service default.
NetworkLogLevel resolveApiLogLevel({
  required NetworkLogLevel serviceLevel,
  bool? enableLogs,
}) {
  if (enableLogs == true) return NetworkLogLevel.full;
  if (enableLogs == false) return NetworkLogLevel.none;
  return serviceLevel;
}
