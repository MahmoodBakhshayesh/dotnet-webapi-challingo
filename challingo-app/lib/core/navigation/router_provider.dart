
import '/core/navigation/app_routes.dart';
import '/features/home/home_view.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../features/login/login_view.dart';
import '../../features/profile/profile_view.dart';
import '../data/app_data.dart';
import 'app_middlewares.dart';
import 'app_route_names.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: kDebugMode,
    navigatorKey: AppRoutes.rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: AppData.instance,
    redirect: AppMiddlewares.authRoutesMiddleware,
    routes: [
      GoRoute(
        path: '/login',
        name: AppRouteNames.login,
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/home',
        name: AppRouteNames.home,
        builder: (context, state) => const HomeView(),
      ),
      GoRoute(
        path: '/profile',
        name: AppRouteNames.profile,
        builder: (context, state) => const ProfileView(),
      ),
      // mbkh_feat:routes (anchor — the mbkh_feat post_gen hook inserts new routes above this line)
    ],
  );
});
