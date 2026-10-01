import '../interfaces/base_result.dart';
import '../interfaces/failure_code.dart';
import '../models/networking/network_response.dart';

/// Parses the standard `{ "Body": { "Response": ... } }` API envelope.
mixin RemoteResponseParser {
  Map<String, dynamic> bodyMap(NetworkResponse nr) {
    final data = nr.data;
    if (data is! Map) {
      throw FormatException('Expected map response body');
    }
    final body = data['Body'];
    if (body is! Map) {
      throw FormatException('Expected Body in response');
    }
    return Map<String, dynamic>.from(body);
  }

  dynamic bodyResponse(NetworkResponse nr) => bodyMap(nr)['Response'];

  T? parseBodyObjectOrNull<T>(
    NetworkResponse nr,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (!nr.success) return null;
    final response = bodyResponse(nr);
    if (response is! Map) return null;
    return fromJson(Map<String, dynamic>.from(response));
  }

  List<T>? parseBodyListOrNull<T>(
    NetworkResponse nr,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (!nr.success) return null;
    final response = bodyResponse(nr);
    if (response is! List) return null;
    return response
        .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  T parseBodyObject<T>(
    NetworkResponse nr,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final value = parseBodyObjectOrNull(nr, fromJson);
    if (value == null) {
      final message = nr.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw ServerFailure(message);
      }
      throw ServerFailure(
        FailureMessages.emptyResponse,
        failureCode: FailureCode.emptyResponse,
      );
    }
    return value;
  }

  List<T> parseBodyList<T>(
    NetworkResponse nr,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final value = parseBodyListOrNull(nr, fromJson);
    if (value == null) {
      final message = nr.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw ServerFailure(message);
      }
      throw ServerFailure(
        FailureMessages.emptyResponse,
        failureCode: FailureCode.emptyResponse,
      );
    }
    return value;
  }
}
