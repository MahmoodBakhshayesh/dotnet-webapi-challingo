import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/competition_models.dart';
import '../../features/boards/boards_screen.dart';
import '../../features/groups/groups_screen.dart';
import '../../features/hub/hub_screen.dart';
import '../../features/shell/app_shell.dart';
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
        // Keep an invite link (/g/CODE) through sign-in.
        SessionStatus.signedOut => path == '/welcome'
            ? null
            : path.startsWith('/g/')
            ? '/welcome?next=${Uri.encodeQueryComponent(path)}'
            : '/welcome',
        SessionStatus.signedIn => (path == '/splash' || path == '/welcome')
            ? (state.uri.queryParameters['next']?.startsWith('/g/') == true ? state.uri.queryParameters['next'] : '/home')
            : null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', name: AppRouteNames.home, builder: (context, state) => const HubScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/boards',
              builder: (context, state) => BoardsScreen(
                initialPeriod: BoardPeriod.values.where((p) => p.name == state.uri.queryParameters['period']).firstOrNull,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/groups', builder: (context, state) => const GroupsScreen())]),
        ],
      ),
      GoRoute(path: '/boards/round/:id', builder: (context, state) => RoundBoardScreen(challengeId: state.pathParameters['id']!)),
      GoRoute(path: '/groups/:id', builder: (context, state) => GroupDetailScreen(groupId: state.pathParameters['id']!)),
      GoRoute(path: '/g/:code', builder: (context, state) => InviteScreen(code: state.pathParameters['code']!)),
      GoRoute(
        path: '/play/:game',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return PlayScreen(
            game: GameKind.fromKey(state.pathParameters['game']!) ?? GameKind.sudoku,
            challengeId: q['challenge'],
            kind: ChallengeKind.values[int.tryParse(q['kind'] ?? '') ?? 0],
            sequence: int.tryParse(q['seq'] ?? '') ?? 0,
          );
        },
      ),
      // mbkh_feat:routes (anchor — the mbkh_feat post_gen hook inserts new routes above this line)
    ],
  );
});
