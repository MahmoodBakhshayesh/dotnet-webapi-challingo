/// A class containing constants for all the route names in the application.
///
/// This provides a single source of truth for routing and prevents typos,
/// allowing the compiler to catch errors instead of causing runtime failures.
class AppRouteNames {
  AppRouteNames._(); // Private constructor to prevent instantiation.

  static const String login = 'login';
  static const String home = 'home';
  static const String profile = 'profile';
  // mbkh_feat:route-names (anchor — the mbkh_feat post_gen hook inserts new route names above this line)
}
