import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/context_extension.dart';
import '../../core/interfaces/base_navigation_service.dart';
import '../../di.dart';

/// Standard back arrow for app bars; pops the current route unless a custom
/// [onPressed] is given.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  void onBackButtonPressed() => locator<BaseNavigationService>().pop();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? context.pop,
      tooltip: context.localizations.back,
      color: Colors.white,
      icon: const Icon(Icons.arrow_back_ios_new_outlined),
    );
  }
}
