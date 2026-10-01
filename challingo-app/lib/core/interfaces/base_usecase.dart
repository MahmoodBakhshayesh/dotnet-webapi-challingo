import 'package:dio/dio.dart';

import '../data/app_data.dart';
import '../helpers/network_exception.dart';
import '../helpers/use_case_guard.dart';
import 'base_failure.dart';
import 'base_result.dart';

/// Request objects implement `validate()` if needed.
abstract class Request {
  final cancelToken = CancelToken();

  /// Return a Failure to stop the use case, or null if valid.
  Failure? validate();

  Map<String, dynamic> toJson();

  /// Standard API envelope: `{ "Body": { "Request": { ... } } }` with optional token.
  static Map<String, dynamic> apiEnvelope(Map<String, dynamic> requestFields) {
    return {
      'Body': {
        if (AppData.instance.hasToken) 'Token': AppData.instance.token,
        'Request': requestFields,
      },
    };
  }

  /// REST JSON body (no envelope).
  static Map<String, dynamic> plainJson(Map<String, dynamic> fields) => fields;

  /// Legacy envelope when an [execution] name is required on the body.
  static Map<String, dynamic> createRequestJson({
    required String execution,
    required Map<String, dynamic>? body,
  }) {
    final requestBody = {
      if (AppData.instance.hasToken) 'Token': AppData.instance.token,
      'Request': {
        ...?body,
      },
    };

    return {
      'Body': {'Execution': execution, ...requestBody},
    };
  }
}

/// Optional response marker (handy for typing/mapping).
abstract class UseCaseResponse {
  final bool success;
  final String message;
  final dynamic error;

  const UseCaseResponse({
    this.success = true,
    this.message = '',
    this.error,
  });

  const UseCaseResponse.fail(this.message, {this.error}) : success = false;
}

abstract class UseCase<Out extends Object, In extends Request> {
  const UseCase();

  void customErrorHandler(NetworkException networkException) {
    if (networkException.wasCancelled != true) {
      FailureBus.I.emit(FailureNotice.fromNetworkException(networkException));
    }
  }

  Future<Result<Out>> call(In request, {bool emitFailures = true}) {
    return guardUseCaseCall(
      request,
      () async => Ok(await execute(request)),
      onNetworkException: emitFailures ? customErrorHandler : null,
      emitFailures: emitFailures,
    );
  }

  Future<Out> execute(In request);
}

/// Maps a repository [UseCaseResponse] into domain data and surfaces failures as [Err].
abstract class RepositoryUseCase<T extends Object, R extends UseCaseResponse, In extends Request>
    extends UseCase<T, In> {
  const RepositoryUseCase();

  Future<R> fetchFromRepository(In request);

  /// Extract domain payload from a successful repository response. Return null if missing.
  T? dataFromResponse(R response);

  /// Message when [dataFromResponse] returns null despite `success: true`.
  String missingDataMessage(R response) => 'Missing response data';

  @override
  Future<Result<T>> call(In request, {bool emitFailures = true}) {
    return guardUseCaseCall(
      request,
      () async {
        final response = await fetchFromRepository(request);
        if (!response.success) {
          emitRepositoryFailure(
            response.message,
            emit: emitFailures,
            error: response.error,
          );
          return Err(repositoryFailure(response.message, error: response.error));
        }
        final data = dataFromResponse(response);
        if (data == null) {
          final msg = missingDataMessage(response);
          emitRepositoryFailure(msg, emit: emitFailures, error: response.error);
          return Err(repositoryFailure(msg, error: response.error));
        }
        return Ok(data);
      },
      onNetworkException: emitFailures ? customErrorHandler : null,
      emitFailures: emitFailures,
    );
  }

  @override
  Future<T> execute(In request) async {
    final response = await fetchFromRepository(request);
    if (!response.success) {
      emitRepositoryFailure(response.message, error: response.error);
      throw repositoryFailure(response.message, error: response.error);
    }
    final data = dataFromResponse(response);
    if (data == null) {
      final msg = missingDataMessage(response);
      emitRepositoryFailure(msg, error: response.error);
      throw repositoryFailure(msg, error: response.error);
    }
    return data;
  }
}

/// Side-effect repository calls with no payload on success.
abstract class RepositoryVoidUseCase<R extends UseCaseResponse, In extends Request>
    extends UseCase<Unit, In> {
  const RepositoryVoidUseCase();

  Future<R> fetchFromRepository(In request);

  @override
  Future<Result<Unit>> call(In request, {bool emitFailures = true}) {
    return guardUseCaseCall(
      request,
      () async {
        final response = await fetchFromRepository(request);
        if (!response.success) {
          emitRepositoryFailure(
            response.message,
            emit: emitFailures,
            error: response.error,
          );
          return Err(repositoryFailure(response.message, error: response.error));
        }
        return Ok(Unit.value);
      },
      onNetworkException: emitFailures ? customErrorHandler : null,
      emitFailures: emitFailures,
    );
  }

  @override
  Future<Unit> execute(In request) async {
    final response = await fetchFromRepository(request);
    if (!response.success) {
      emitRepositoryFailure(response.message, error: response.error);
      throw repositoryFailure(response.message, error: response.error);
    }
    return Unit.value;
  }
}
