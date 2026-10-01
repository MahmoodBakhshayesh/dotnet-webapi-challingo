class Apis {
  Apis._();

  /// Configured at project generation via Mason `base_url`.
  static const String _origin = 'https:&#x2F;&#x2F;example.com';

  static const String baseUrl = '$_origin/api/';
  static const String photoBaseUrl = _origin;

  /// SignalR hub (API `Realtime__HubPath`). Used by `RealtimeService`.
  static const String hubUrl = '$_origin/hubs/app';
}
