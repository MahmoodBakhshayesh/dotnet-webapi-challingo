import 'package:dio/dio.dart';

import '../../di.dart';
import '../helpers/api_service.dart';
import 'api_models.dart';

/// A failed API call, with the server's message when it sent one.
class ApiFailure implements Exception {
  const ApiFailure(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Typed client for the Challingo API. Uses the app's [ApiService] (which adds the bearer token) and
/// retries once after [onUnauthorized] refreshes an expired access token.
class ChallingoApi {
  ChallingoApi({ApiService? api}) : _api = api ?? locator<ApiService>();

  final ApiService _api;

  /// Set by the session: refreshes tokens and returns true when a retry makes sense.
  Future<bool> Function()? onUnauthorized;

  // --- Auth ---------------------------------------------------------------

  Future<AuthTokens> createGuest(String timeZoneId) async =>
      _tokens(await _send('POST', 'auth/guest', body: {'timeZoneId': timeZoneId}, authRetry: false));

  /// Sign-in code for an existing account (404 when the email has no account).
  Future<void> requestSignInCode(String email) => _send('POST', 'auth/otp/request', body: {'email': email}, authRetry: false);

  Future<AuthTokens> verifySignInCode(String email, String code) async =>
      _tokens(await _send('POST', 'auth/otp/verify', body: {'email': email, 'code': code}, authRetry: false));

  /// Sign-up code for a new email (409 when it is already registered).
  Future<void> requestSignUpCode(String email) => _send('POST', 'auth/register/email', body: {'email': email}, authRetry: false);

  Future<AuthTokens> verifySignUpCode(String email, String code) async =>
      _tokens(await _send('POST', 'auth/register/email/confirm', body: {'email': email, 'code': code}, authRetry: false));

  /// Exchanges a refresh token (the access token may be expired).
  Future<AuthTokens> refresh(String accessToken, String refreshToken) async {
    final body = await _send('POST', 'auth/refresh', body: {'token': accessToken, 'refreshToken': refreshToken}, authRetry: false);
    return AuthTokens.fromJson((body as Map)['token'].cast<String, dynamic>());
  }

  // --- Profile ------------------------------------------------------------

  Future<Me> me() async => Me.fromJson(await _map('GET', 'me'));

  Future<Me> setDisplayName(String name) async => Me.fromJson(await _map('PUT', 'me', body: {'displayName': name}));

  Future<Me> setTimeZone(String timeZoneId) async => Me.fromJson(await _map('PUT', 'me/timezone', body: {'timeZoneId': timeZoneId}));

  /// Guest upgrade: code to the email that will be attached to this account.
  Future<void> requestEmailLink(String email) => _send('POST', 'me/email/request', body: {'email': email});

  Future<AuthTokens> confirmEmailLink(String email, String code) async =>
      _tokens(await _send('POST', 'me/email/confirm', body: {'email': email, 'code': code}));

  // --- Puzzle engine ------------------------------------------------------

  Future<List<String>> games() async => ((await _send('GET', 'challenges/games')) as List).cast<String>();

  Future<ChallengeInfo> createPractice(String gameKey) async =>
      ChallengeInfo.fromJson(await _map('POST', 'challenges/practice/$gameKey'));

  Future<AttemptStart> start(String challengeId) async =>
      AttemptStart.fromJson(await _map('POST', 'challenges/$challengeId/start'));

  Future<MoveResult> move(AttemptStart attempt, Map<String, dynamic> move) async => MoveResult.fromJson(
    await _map('POST', 'challenges/attempts/${attempt.attemptId}/move', body: {'attemptToken': attempt.attemptToken, 'move': move}),
  );

  Future<SubmitResult> submit(AttemptStart attempt, Map<String, dynamic> submission, {List<Object?>? moves}) async =>
      SubmitResult.fromJson(
        await _map('POST', 'challenges/attempts/${attempt.attemptId}/submit', body: {
          'attemptToken': attempt.attemptToken,
          'submission': submission,
          'moves': ?moves,
        }),
      );

  // --- Transport ----------------------------------------------------------

  AuthTokens _tokens(Object? body) => AuthTokens.fromJson(((body as Map)['token'] as Map).cast<String, dynamic>());

  Future<Map<String, dynamic>> _map(String method, String path, {Object? body}) async =>
      ((await _send(method, path, body: body)) as Map).cast<String, dynamic>();

  /// Returns the envelope's `body`; throws [ApiFailure] with the server message otherwise.
  Future<Object?> _send(String method, String path, {Object? body, bool authRetry = true}) async {
    final res = switch (method) {
      'GET' => await _api.get(path, throwOnFailure: false),
      'PUT' => await _api.put(path, body: body, throwOnFailure: false),
      _ => await _api.post(path, body: body, throwOnFailure: false),
    };

    if (res.statusCode == 401 && authRetry && onUnauthorized != null && await onUnauthorized!()) {
      return _send(method, path, body: body, authRetry: false);
    }

    final data = res.data is Map ? (res.data as Map) : const {};
    if (!res.success) {
      final raw = res.raw;
      final offline = raw is DioException && raw.response == null;
      throw ApiFailure(
        offline ? 'No connection. Check your internet and try again.' : (data['message'] as String? ?? res.message ?? 'Something went wrong.'),
        res.statusCode,
      );
    }
    return data['body'];
  }
}
