import 'dart:async';
import 'dart:developer';

import 'package:signalr_netcore/signalr_client.dart';

import '../constants/apis.dart';
import '../data/app_data.dart';

/// Server → app push channel over SignalR (API hub at `Apis.hubUrl`).
///
/// Opt-in: call [bindToSession] once after `AppData.instance.init()` to connect
/// while a token exists and disconnect on logout. Then:
///
/// ```dart
/// final off = RealtimeService.instance.on('scoreChanged', (payload) { ... });
/// await RealtimeService.instance.subscribe('leaderboard:daily');
/// off(); // in dispose
/// ```
///
/// Every connection is in the `user:{id}` group automatically, so per-user
/// events need no subscribe. Topics are re-joined after reconnects.
class RealtimeService {
  RealtimeService._();

  static final instance = RealtimeService._();

  HubConnection? _connection;
  Future<void>? _connecting;
  bool _boundToSession = false;
  final Set<String> _topics = {};
  final Map<String, List<void Function(Object? payload)>> _handlers = {};
  final StreamController<HubConnectionState> _states = StreamController.broadcast();

  Stream<HubConnectionState> get states => _states.stream;
  HubConnectionState get state => _connection?.state ?? HubConnectionState.Disconnected;
  bool get isConnected => state == HubConnectionState.Connected;

  /// Connects whenever [AppData] holds a token and disconnects when it is cleared.
  void bindToSession() {
    if (_boundToSession) return;
    _boundToSession = true;
    AppData.instance.addListener(_syncWithSession);
    _syncWithSession();
  }

  void _syncWithSession() {
    if (AppData.instance.hasToken) {
      unawaited(connect());
    } else {
      unawaited(disconnect());
    }
  }

  Future<void> connect() {
    if (isConnected) return Future.value();
    return _connecting ??= _start().whenComplete(() => _connecting = null);
  }

  Future<void> _start() async {
    final connection = _connection ?? _build();
    _connection = connection;
    if (connection.state != HubConnectionState.Disconnected) return;
    try {
      await connection.start();
      _states.add(connection.state ?? HubConnectionState.Disconnected);
      await _resubscribe();
    } catch (e) {
      log('Realtime connect failed: $e', name: 'RealtimeService');
      _states.add(HubConnectionState.Disconnected);
    }
  }

  HubConnection _build() {
    final connection = HubConnectionBuilder()
        .withUrl(
          Apis.hubUrl,
          options: HttpConnectionOptions(accessTokenFactory: () async => AppData.instance.token ?? ''),
        )
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
        .build();

    connection.onreconnecting(({error}) => _states.add(HubConnectionState.Reconnecting));
    connection.onreconnected(({connectionId}) {
      _states.add(HubConnectionState.Connected);
      // Groups belong to the old connection id: join topics again.
      unawaited(_resubscribe());
    });
    connection.onclose(({error}) => _states.add(HubConnectionState.Disconnected));

    for (final method in _handlers.keys) {
      connection.on(method, (args) => _dispatch(method, args));
    }
    return connection;
  }

  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    if (connection != null && connection.state != HubConnectionState.Disconnected) {
      await connection.stop();
    }
    _states.add(HubConnectionState.Disconnected);
  }

  /// Listens to a server method (e.g. `scoreChanged`). Returns a function that removes the handler.
  void Function() on(String method, void Function(Object? payload) handler) {
    final handlers = _handlers.putIfAbsent(method, () {
      _connection?.on(method, (args) => _dispatch(method, args));
      return [];
    });
    handlers.add(handler);
    return () {
      handlers.remove(handler);
      if (handlers.isEmpty) {
        _handlers.remove(method);
        _connection?.off(method);
      }
    };
  }

  void _dispatch(String method, List<Object?>? args) {
    final payload = (args == null || args.isEmpty) ? null : args.first;
    for (final handler in List.of(_handlers[method] ?? const [])) {
      handler(payload);
    }
  }

  /// Joins a topic group such as `challenge:{id}` (lowercase, no `user:` prefix).
  Future<void> subscribe(String topic) async {
    _topics.add(topic);
    if (isConnected) await _connection!.invoke('Subscribe', args: [topic]);
  }

  Future<void> unsubscribe(String topic) async {
    _topics.remove(topic);
    if (isConnected) await _connection!.invoke('Unsubscribe', args: [topic]);
  }

  /// Server UTC time — use for countdowns instead of the device clock.
  Future<DateTime?> serverTime() async {
    if (!isConnected) return null;
    final value = await _connection!.invoke('Ping');
    return value is String ? DateTime.tryParse(value)?.toUtc() : null;
  }

  Future<void> _resubscribe() async {
    for (final topic in _topics) {
      try {
        await _connection?.invoke('Subscribe', args: [topic]);
      } catch (e) {
        log('Realtime resubscribe $topic failed: $e', name: 'RealtimeService');
      }
    }
  }
}
