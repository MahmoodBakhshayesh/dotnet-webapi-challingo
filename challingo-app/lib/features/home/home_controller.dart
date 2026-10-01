import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../../core/controllers/base_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/navigation/app_route_names.dart';

final homeControllerProvider = Provider.autoDispose((ref) {
  final controller = HomeController(ref);
  Future.microtask(controller.init);
  ref.onDispose(() => controller.dispose());
  return controller;
});

class HomeController extends BaseController {
  HomeController(super.ref);

  @override
  void init() {
    loadCachedData();
    super.init();
  }

  void goProfile(BuildContext context) {
    // ref.read(profileControllerProvider).logout(context);
    context.pushNamed(AppRouteNames.profile);
  }

  Future<void> loadCachedData() async {}
}
