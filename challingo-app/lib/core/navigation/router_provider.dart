import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/hub/hub_screen.dart';
import '../../features/play/game_catalog.dart';
import '../../features/play/play_screen.dart';
import '../../features/welcome/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../session/session_controller.dart';
import 'app_route_names.dart';
import 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Start restoring the session right away; the gate below drives redirects.
  ref.read(sessionProvider);
  final gate = SessionGate.instance;

  return GoRouter(
    debugLogDiagnostics: kDebugMode,
    navigatorKey: AppRoutes.rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: gate,
    redirect: (context, state) {
      final path = state.uri.path;
      return switch (gate.status) {
        SessionStatus.unknown => path == '/splash' ? null : '/splash',
        SessionStatus.signedOut => path == '/welcome' ? null : '/welcome',
        SessionStatus.signedIn => (path == '/splash' || path == '/welcome') ? '/home' : null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/home', name: AppRouteNames.home, builder: (context, state) => const HubScreen()),
      GoRoute(
        path: '/play/:game',
        builder: (context, state) => PlayScreen(
          game: GameKind.fromKey(state.pathParameters['game']!) ?? GameKind.sudoku,
          challengeId: state.uri.queryParameters['challenge'],
        ),
      ),
      // mbkh_feat:routes (anchor — the mbkh_feat post_gen hook inserts new routes above this line)
    ],
  );
});
