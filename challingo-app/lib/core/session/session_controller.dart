import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_models.dart';
import '../api/challingo_api.dart';
import '../data/app_data.dart';

enum SessionStatus { unknown, signedOut, signedIn }

/// What the router needs: whether the session is known yet and whether someone is signed in.
class SessionGate extends ChangeNotifier {
  SessionGate._();

  static final instance = SessionGate._();

  SessionStatus _status = SessionStatus.unknown;
  SessionStatus get status => _status;

  void set(SessionStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }
}

final challingoApiProvider = Provider<ChallingoApi>((ref) => ChallingoApi());

/// The signed-in player (null when signed out). Loading while the saved session is restored at launch.
final sessionProvider = AsyncNotifierProvider<SessionController, Me?>(SessionController.new);

class SessionController extends AsyncNotifier<Me?> {
  static const _accessKey = 'auth_token';
  static const _refreshKey = 'auth_refresh_token';

  late ChallingoApi _api;
  late SharedPreferences _prefs;
  Future<bool>? _refreshing;

  @override
  Future<Me?> build() async {
    _api = ref.read(challingoApiProvider);
    _api.onUnauthorized = _refresh;
    _prefs = await SharedPreferences.getInstance();

    if (_prefs.getString(_refreshKey) == null) {
      SessionGate.instance.set(SessionStatus.signedOut);
      return null;
    }
    // AppData loads its token asynchronously at startup; set it now so the first request is authenticated.
    AppData.instance.setToken(_prefs.getString(_accessKey));
    try {
      return await _enter();
    } on ApiFailure catch (f) {
      // Offline at launch: keep the tokens and let the player retry; only a rejected session signs out.
      if (f.statusCode == 401 || f.statusCode == 404) {
        await _clear();
        return null;
      }
      rethrow;
    }
  }

  /// "Play now": a guest account in the device's time zone.
  Future<void> playAsGuest() => _run(() async {
    await _save(await _api.createGuest(await deviceTimeZone()));
    return _enter();
  });

  /// Sends a sign-in code; falls back to a sign-up code when the email has no account yet.
  /// Returns true when the code is for a new account.
  Future<bool> requestEmailCode(String email) async {
    try {
      await _api.requestSignInCode(email);
      return false;
    } on ApiFailure catch (f) {
      if (f.statusCode != 404) rethrow;
      await _api.requestSignUpCode(email);
      return true;
    }
  }

  Future<void> verifyEmailCode(String email, String code, {required bool isNewAccount}) => _run(() async {
    await _save(isNewAccount ? await _api.verifySignUpCode(email, code) : await _api.verifySignInCode(email, code));
    return _enter();
  });

  /// Guest upgrade: attaches the email to this same account (stars, streak and history stay).
  Future<void> requestEmailLink(String email) => _api.requestEmailLink(email);

  Future<void> confirmEmailLink(String email, String code) => _run(() async {
    await _save(await _api.confirmEmailLink(email, code));
    return _api.me();
  });

  Future<void> reload() => _run(_api.me);

  Future<void> signOut() async {
    await _clear();
    state = const AsyncData(null);
  }

  static Future<String> deviceTimeZone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return 'Etc/UTC';
    }
  }

  /// Loads the profile; a brand-new email account still on UTC gets the device zone (the server allows that once for free).
  Future<Me> _enter() async {
    var me = await _api.me();
    if (me.timeZoneId == 'Etc/UTC' && me.nextTimeZoneChangeAtUtc == null) {
      final zone = await deviceTimeZone();
      if (zone != 'Etc/UTC') {
        try {
          me = await _api.setTimeZone(zone);
        } on ApiFailure {
          // Unknown zone name on this device: stay on UTC.
        }
      }
    }
    AppData.instance.setUserId(me.userId);
    SessionGate.instance.set(SessionStatus.signedIn);
    return me;
  }

  Future<void> _run(Future<Me> Function() action) async {
    state = await AsyncValue.guard(action);
    if (state.hasError) {
      final error = state.error!;
      // Keep the previous player on screen; surface the error to the caller.
      state = AsyncData(state.value);
      throw error;
    }
  }

  /// Single-flight refresh shared by every request that hit a 401.
  Future<bool> _refresh() => _refreshing ??= () async {
    try {
      final access = _prefs.getString(_accessKey);
      final refresh = _prefs.getString(_refreshKey);
      if (access == null || refresh == null) return false;
      await _save(await _api.refresh(access, refresh));
      return true;
    } on ApiFailure {
      await _clear();
      state = const AsyncData(null);
      return false;
    } finally {
      _refreshing = null;
    }
  }();

  Future<void> _save(AuthTokens tokens) async {
    await _prefs.setString(_accessKey, tokens.accessToken);
    await _prefs.setString(_refreshKey, tokens.refreshToken);
    AppData.instance.setToken(tokens.accessToken);
  }

  Future<void> _clear() async {
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
    AppData.instance.setToken(null);
    AppData.instance.setUserId(null);
    SessionGate.instance.set(SessionStatus.signedOut);
  }
}
