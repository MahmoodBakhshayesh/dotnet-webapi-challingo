import '../interfaces/base_usecase.dart';
import 'error_message_formatter.dart';
import 'repository_caught_error.dart';

typedef UseCaseResponseFactory<R extends UseCaseResponse> = R Function({
  bool success,
  String message,
  dynamic error,
});

/// Runs [action] and maps to a [UseCaseResponse] without try/catch in every repository.
///
/// When the remote returns `null`, the response is failed automatically — you do not
/// need to throw or check null in the repository.
///
/// ```dart
/// return mapUseCaseResponse(
///   () => remote.login(request),
///   onSuccess: (data) => LoginResponse(loginData: data),
///   create: LoginResponse.new,
/// );
/// ```
Future<R> mapUseCaseResponse<T extends Object, R extends UseCaseResponse>(
  Future<T?> Function() action, {
  required R Function(T data) onSuccess,
  required UseCaseResponseFactory<R> create,
  String messageOnNull = 'Empty response',
}) async {
  try {
    final data = await action();
    if (data == null) {
      return create(success: false, message: messageOnNull);
    }
    return onSuccess(data);
  } catch (error, stackTrace) {
    return create(
      success: false,
      message: ErrorMessageFormatter.format(error, stackTrace),
      error: RepositoryCaughtError(error, stackTrace),
    );
  }
}

/// For side-effect calls that return nothing on success (register, seeStory, etc.).
Future<R> mapUseCaseResponseVoid<R extends UseCaseResponse>(
  Future<void> Function() action, {
  required R Function() onSuccess,
  required UseCaseResponseFactory<R> create,
}) async {
  try {
    await action();
    return onSuccess();
  } catch (error, stackTrace) {
    return create(
      success: false,
      message: ErrorMessageFormatter.format(error, stackTrace),
      error: RepositoryCaughtError(error, stackTrace),
    );
  }
}

/// For remotes that return `bool` instead of throwing on failure.
Future<R> mapUseCaseResponseBool<R extends UseCaseResponse>(
  Future<bool> Function() action, {
  required R Function() onSuccess,
  required UseCaseResponseFactory<R> create,
  String messageOnFailure = 'Operation failed',
}) async {
  try {
    final ok = await action();
    if (!ok) {
      return create(success: false, message: messageOnFailure);
    }
    return onSuccess();
  } catch (error, stackTrace) {
    return create(
      success: false,
      message: ErrorMessageFormatter.format(error, stackTrace),
      error: RepositoryCaughtError(error, stackTrace),
    );
  }
}
