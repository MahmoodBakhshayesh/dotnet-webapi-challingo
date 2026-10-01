
import '../../helpers/nullable.dart';

class NetworkResponse {
  final bool success;
  final int? statusCode;
  final String? message;
  final dynamic data; // decoded JSON or raw payload
  final dynamic raw; // raw Dio Response or error
  final Duration duration;

  const NetworkResponse({
    required this.success,
    required this.statusCode,
    required this.message,
    required this.data,
    required this.raw,
    required this.duration,
  });

  const NetworkResponse.empty() : success = false, statusCode = null, message = null, data = null, raw = null, duration = Duration.zero;

  NetworkResponse copyWith({
    bool? success,
    Nullable<int?>? statusCode,
    Nullable<String?>? message,
    Nullable<dynamic>? data,
    Nullable<dynamic>? raw,
    Duration? duration,
  }) => NetworkResponse(
    success: success ?? this.success,
    statusCode: statusCode != null ? statusCode.value : this.statusCode,
    message: message != null ? message.value : this.message,
    data: data != null ? data.value : this.data,
    raw: raw != null ? raw.value : this.raw,
    duration: duration ?? this.duration,
  );

  @override
  String toString() =>
      message ?? 'NetworkResponse(success: $success, code: $statusCode, msg: $message, took: ${duration.inMilliseconds}ms)';
}
