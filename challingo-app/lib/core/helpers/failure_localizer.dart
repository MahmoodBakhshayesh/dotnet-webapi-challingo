import '../../l10n/app_localizations.dart';
import '../interfaces/base_result.dart';
import '../interfaces/failure_code.dart';

abstract class FailureLocalizer {
  static String localize(AppLocalizations l10n, Failure failure) {
    if (failure.failureCode != null) {
      if (failure is ServerFailure && failure.message.isNotEmpty) {
        final mapped = FailureMessages.codeForMessage(failure.message);
        if (mapped == null) {
          return failure.message;
        }
      }
      return _messageForCode(l10n, failure.failureCode!);
    }

    return failure.message.isNotEmpty ? failure.message : l10n.unknownError;
  }

  static String _messageForCode(AppLocalizations l10n, FailureCode code) {
    return switch (code) {
      FailureCode.emptyResponse => l10n.emptyResponse,
      FailureCode.requestFailed => l10n.requestFailed,
      FailureCode.deleteFailed => l10n.deleteFailed,
      FailureCode.networkError => l10n.networkError,
      FailureCode.unknown => l10n.unknownError,
    };
  }
}
