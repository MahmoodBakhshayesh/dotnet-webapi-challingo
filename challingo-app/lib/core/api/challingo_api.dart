import 'package:dio/dio.dart';

import '../../di.dart';
import '../helpers/api_service.dart';
import 'api_models.dart';
import 'competition_models.dart';

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

  // --- Competition --------------------------------------------------------

  Future<Lobby> lobby() async => Lobby.fromJson(await _map('GET', 'competition/lobby'));

  /// [gameKey] is required for day / week / month / all-time boards. [key]: challenge id (run), UTC date,
  /// ISO week, `2026-10`; null = current.
  Future<Board> board(BoardPeriod period, {String? gameKey, String? key, BoardScope scope = BoardScope.global, String? groupId, int limit = 50}) async {
    final query = {
      'period': period.index,
      'gameKey': ?gameKey,
      'key': ?key,
      'scope': scope.index,
      'groupId': ?groupId,
      'limit': limit,
    }.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent('${e.value}')}').join('&');
    return Board.fromJson(await _map('GET', 'competition/boards?$query'));
  }

  // --- Lottery ------------------------------------------------------------

  Future<Lottery> lotteryToday() async => Lottery.fromJson(await _map('GET', 'lottery/today'));

  /// [number]: ten digits, or null for a random "lucky dip".
  Future<Lottery> pickLottery(String? number) async => Lottery.fromJson(await _map('POST', 'lottery/pick', body: {'number': number}));

  Future<List<Lottery>> lotteryHistory() async =>
      [for (final d in (await _send('GET', 'lottery/history')) as List) Lottery.fromJson((d as Map).cast<String, dynamic>())];

  // --- Groups -------------------------------------------------------------

  Future<List<GroupInfo>> groups() async =>
      [for (final g in (await _send('GET', 'groups')) as List) GroupInfo.fromJson((g as Map).cast<String, dynamic>())];

  Future<GroupInfo> createGroup(String name) async => GroupInfo.fromJson(await _map('POST', 'groups', body: {'name': name}));

  Future<GroupInvite> previewInvite(String code) async =>
      GroupInvite.fromJson(await _map('GET', 'groups/invite/${Uri.encodeComponent(code)}'));

  /// [code] may be the bare code or the whole invite link.
  Future<GroupInfo> joinGroup(String code) async => GroupInfo.fromJson(await _map('POST', 'groups/join', body: {'code': code}));

  Future<GroupDetail> group(String groupId) async => GroupDetail.fromJson(await _map('GET', 'groups/$groupId'));

  Future<void> leaveGroup(String groupId) => _send('DELETE', 'groups/$groupId/membership');

  // --- Transport ----------------------------------------------------------

  AuthTokens _tokens(Object? body) => AuthTokens.fromJson(((body as Map)['token'] as Map).cast<String, dynamic>());

  Future<Map<String, dynamic>> _map(String method, String path, {Object? body}) async =>
      ((await _send(method, path, body: body)) as Map).cast<String, dynamic>();

  /// Returns the envelope's `body`; throws [ApiFailure] with the server message otherwise.
  Future<Object?> _send(String method, String path, {Object? body, bool authRetry = true}) async {
    final res = switch (method) {
      'GET' => await _api.get(path, throwOnFailure: false),
      'PUT' => await _api.put(path, body: body, throwOnFailure: false),
      'DELETE' => await _api.delete(path, throwOnFailure: false),
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
