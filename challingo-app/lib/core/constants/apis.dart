class Apis {
  Apis._();

  /// API origin. Override per build: `flutter run --dart-define=API_ORIGIN=https://api.example.com`.
  /// Default suits the iOS simulator; the Android emulator reaches the host at http://10.0.2.2:5128.
  static const String _origin = String.fromEnvironment('API_ORIGIN', defaultValue: 'http://localhost:5128');

  static const String baseUrl = '$_origin/api/';
  static const String photoBaseUrl = _origin;

  /// SignalR hub (API `Realtime__HubPath`). Used by `RealtimeService`.
  static const String hubUrl = '$_origin/hubs/app';
}
