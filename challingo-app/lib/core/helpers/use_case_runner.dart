import '../interfaces/base_result.dart';
import '../interfaces/base_usecase.dart';

/// Runs a [UseCase] and returns the success value, rethrowing [Failure] on error.
Future<T> runUseCase<T extends Object, In extends Request>(
  UseCase<T, In> useCase,
  In request, {
  bool notifyOnFailure = true,
}) async {
  final result = await useCase(request, emitFailures: notifyOnFailure);
  return result.fold(
    ok: (value) => value,
    err: (failure) => throw failure,
  );
}

/// Like [runUseCase] but returns null on failure. Does not notify by default.
Future<T?> runUseCaseOrNull<T extends Object, In extends Request>(
  UseCase<T, In> useCase,
  In request, {
  bool notifyOnFailure = false,
}) async {
  final result = await useCase(request, emitFailures: notifyOnFailure);
  return result.fold(
    ok: (value) => value,
    err: (_) => null,
  );
}

/// Returns true when a void use case completes successfully.
Future<bool> runVoidUseCase<In extends Request>(
  UseCase<Unit, In> useCase,
  In request, {
  bool notifyOnFailure = true,
}) async {
  final result = await useCase(request, emitFailures: notifyOnFailure);
  return result.isOk;
}

extension ResultFutureX<T extends Object> on Future<Result<T>> {
  Future<T> requireValue() => then(
        (result) => result.fold(
          ok: (value) => value,
          err: (failure) => throw failure,
        ),
      );
}
