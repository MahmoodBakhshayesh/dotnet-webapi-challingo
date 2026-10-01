import 'login_response.dart';

/// Built-in dev credentials for offline login (no API call).
class OfflineTestLogin {
  static const enabled = true;
  static const username = 'test';
  static const password = 'test';

  static bool matches(String user, String pass) {
    if (!enabled) return false;
    return user.trim() == username && pass == password;
  }

  static LoginResponseData buildResponse() => LoginResponseData(
        accessToken: 'offline-test-token',
        user: UserEntity(
          id: 'offline-test-user',
          phoneNumber: username,
          fullName: 'Test User',
          username: username,
          email: null,
          profileImageUrl: null,
        ),
      );
}
