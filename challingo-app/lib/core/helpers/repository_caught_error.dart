/// Wraps an error caught in [mapUseCaseResponse] so the original [stackTrace] survives
/// until the use case layer logs or presents the failure.
class RepositoryCaughtError {
  final Object error;
  final StackTrace stackTrace;

  const RepositoryCaughtError(this.error, this.stackTrace);
}

Object? unwrapRepositoryCause(Object? error) {
  if (error is RepositoryCaughtError) return error.error;
  return error;
}

StackTrace? unwrapRepositoryStackTrace(Object? error) {
  if (error is RepositoryCaughtError) return error.stackTrace;
  if (error is Error) return error.stackTrace;
  return null;
}
