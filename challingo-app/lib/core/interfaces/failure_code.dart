enum FailureCode {
  emptyResponse,
  requestFailed,
  deleteFailed,
  networkError,
  unknown,
}

abstract final class FailureMessages {
  static const emptyResponse = 'Empty response';
  static const requestFailed = 'Request failed';
  static const deleteFailed = 'Delete failed';

  static FailureCode? codeForMessage(String message) {
    return switch (message) {
      emptyResponse => FailureCode.emptyResponse,
      requestFailed => FailureCode.requestFailed,
      deleteFailed => FailureCode.deleteFailed,
      _ => null,
    };
  }
}
