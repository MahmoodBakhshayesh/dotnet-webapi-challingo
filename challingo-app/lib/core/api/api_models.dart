/// Typed views of the Challingo API's JSON (camelCase, inside the `{status, message, body}` envelope).
library;

import 'competition_models.dart';

DateTime _date(Object? v) => DateTime.parse(v as String).toUtc();
DateTime? _dateOrNull(Object? v) => v == null ? null : DateTime.parse(v as String).toUtc();

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      AuthTokens(accessToken: json['accessToken'] as String, refreshToken: json['refreshToken'] as String);
}

class Me {
  const Me({
    required this.userId,
    required this.displayName,
    required this.isGuest,
    required this.email,
    required this.timeZoneId,
    required this.countryCode,
    this.countryName,
    required this.localDate,
    required this.nextTimeZoneChangeAtUtc,
  });

  final String userId;
  final String displayName;
  final bool isGuest;
  final String? email;
  final String timeZoneId;
  final String? countryCode;

  /// "Germany" for DE.
  final String? countryName;

  /// The player's "today" as computed by the server.
  final String localDate;
  final DateTime? nextTimeZoneChangeAtUtc;

  factory Me.fromJson(Map<String, dynamic> json) => Me(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    isGuest: json['isGuest'] as bool,
    email: json['email'] as String?,
    timeZoneId: json['timeZoneId'] as String,
    countryCode: json['countryCode'] as String?,
    countryName: json['countryName'] as String?,
    localDate: json['localDate'] as String,
    nextTimeZoneChangeAtUtc: _dateOrNull(json['nextTimeZoneChangeAtUtc']),
  );
}

class ChallengeInfo {
  const ChallengeInfo({required this.challengeId, required this.gameKey, required this.closesAtUtc});

  final String challengeId;
  final String gameKey;
  final DateTime closesAtUtc;

  factory ChallengeInfo.fromJson(Map<String, dynamic> json) => ChallengeInfo(
    challengeId: json['challengeId'] as String,
    gameKey: json['gameKey'] as String,
    closesAtUtc: _date(json['closesAtUtc']),
  );
}

/// Server attempt status (matches the API's AttemptStatus).
enum AttemptStatus { inProgress, solved, failed, expired }

AttemptStatus _status(Object? v) => AttemptStatus.values[(v as num).toInt()];

class AttemptStart {
  const AttemptStart({
    required this.attemptId,
    required this.attemptToken,
    required this.gameKey,
    required this.puzzle,
    required this.startedAtUtc,
    required this.closesAtUtc,
    required this.serverNowUtc,
    required this.resumed,
    required this.interactive,
    required this.state,
  });

  final String attemptId;
  final String attemptToken;
  final String gameKey;

  /// Public puzzle JSON — never holds the solution.
  final Map<String, dynamic> puzzle;
  final DateTime startedAtUtc;
  final DateTime closesAtUtc;
  final DateTime serverNowUtc;
  final bool resumed;
  final bool interactive;

  /// Progress of an interactive game when resuming.
  final Map<String, dynamic>? state;

  factory AttemptStart.fromJson(Map<String, dynamic> json) => AttemptStart(
    attemptId: json['attemptId'] as String,
    attemptToken: json['attemptToken'] as String,
    gameKey: json['gameKey'] as String,
    puzzle: (json['puzzle'] as Map).cast<String, dynamic>(),
    startedAtUtc: _date(json['startedAtUtc']),
    closesAtUtc: _date(json['closesAtUtc']),
    serverNowUtc: _date(json['serverNowUtc']),
    resumed: json['resumed'] as bool? ?? false,
    interactive: json['interactive'] as bool? ?? false,
    state: (json['state'] as Map?)?.cast<String, dynamic>(),
  );
}

class MoveResult {
  const MoveResult({required this.status, required this.response, required this.moveCount, required this.elapsedMs, this.standing});

  final AttemptStatus status;
  final Map<String, dynamic> response;
  final int moveCount;
  final int? elapsedMs;

  /// Live rank once a move finished a shared challenge.
  final Standing? standing;

  factory MoveResult.fromJson(Map<String, dynamic> json) => MoveResult(
    status: _status(json['status']),
    response: (json['response'] as Map? ?? const {}).cast<String, dynamic>(),
    moveCount: (json['moveCount'] as num).toInt(),
    elapsedMs: (json['elapsedMs'] as num?)?.toInt(),
    standing: Standing.fromJson(json['standing']),
  );
}

class SubmitResult {
  const SubmitResult({required this.status, required this.solved, required this.elapsedMs, required this.message, required this.result, this.standing});

  final AttemptStatus status;
  final bool solved;
  final int? elapsedMs;

  /// Why a submission was not accepted (the attempt stays open).
  final String? message;
  final Map<String, dynamic>? result;

  /// Live rank in a shared (daily, ranked, Grand) challenge.
  final Standing? standing;

  factory SubmitResult.fromJson(Map<String, dynamic> json) => SubmitResult(
    status: _status(json['status']),
    solved: json['solved'] as bool? ?? false,
    elapsedMs: (json['elapsedMs'] as num?)?.toInt(),
    message: json['message'] as String?,
    result: (json['result'] as Map?)?.cast<String, dynamic>(),
    standing: Standing.fromJson(json['standing']),
  );
}
