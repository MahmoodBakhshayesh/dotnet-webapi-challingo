import '../helpers/failure_logger.dart';
import '../helpers/repository_caught_error.dart';
import '../interfaces/base_usecase.dart';
import '../interfaces/base_result.dart';
import '../helpers/network_exception.dart';
import '../interfaces/base_failure.dart';

Future<Result<T>> guardUseCaseCall<T extends Object, In extends Request>(
  In request,
  Future<Result<T>> Function() run, {
  void Function(NetworkException networkException)? onNetworkException,
  bool emitFailures = true,
}) async {
  final validation = request.validate();
  if (validation != null) {
    if (emitFailures) {
      FailureBus.I.emit(FailureNotice(failure: validation));
    } else {
      FailureLogger.logFailure(validation, muted: true, source: 'validation');
    }
    return Err(validation);
  }

  try {
    return await run();
  } on NetworkException catch (networkException) {
    onNetworkException?.call(networkException);
    if (emitFailures &&
        networkException.wasCancelled != true &&
        onNetworkException == null) {
      FailureBus.I.emit(FailureNotice.fromNetworkException(networkException));
    }
    final failure = networkException.tokenExpired == true
        ? UnAuthenticateFailure(networkException.message)
        : NetworkFailure(
            networkException.message,
            code: networkException.statusCode,
            response: networkException.data,
          );
    if (!emitFailures) {
      FailureLogger.logFailure(failure, muted: true, source: 'network');
    }
    return Err(failure);
  } catch (error, stackTrace) {
    if (error is Failure) {
      if (!emitFailures) {
        FailureLogger.logFailure(error, muted: true, source: 'guard');
      }
      return Err(error);
    }
    final failure = UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace);
    if (emitFailures) {
      FailureBus.I.emit(FailureNotice(failure: failure));
    } else {
      FailureLogger.logFailure(failure, muted: true, source: 'guard');
    }
    return Err(failure);
  }
}

void emitRepositoryFailure(
  String message, {
  bool emit = true,
  Object? error,
}) {
  final failure = repositoryFailure(message, error: error);
  if (emit) {
    FailureBus.I.emit(FailureNotice(failure: failure));
  } else {
    FailureLogger.logFailure(failure, muted: true, source: 'repository');
  }
}

Failure repositoryFailure(String message, {Object? error}) {
  final cause = unwrapRepositoryCause(error);
  final stackTrace = unwrapRepositoryStackTrace(error);
  return ServerFailure(
    message,
    cause: cause ?? error,
    stackTrace: stackTrace,
  );
}
