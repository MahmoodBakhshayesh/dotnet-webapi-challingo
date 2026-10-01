import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../interfaces/base_success.dart';
import '../navigation/app_routes.dart';
import '../theme/app_colors.dart';

abstract class SuccessPresenter {
  static BuildContext? get _rootContext => AppRoutes.rootContext;

  static bool _presenting = false;

  /// Schedules UI feedback after the current frame so we never call
  /// [toastification] during build.
  static void show(SuccessNotice notice) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canPresent()) return;
      _presentNow(notice);
    });
  }

  static bool _canPresent() {
    final context = _rootContext;
    return context != null && context.mounted;
  }

  static void _presentNow(SuccessNotice notice) {
    if (_presenting || !_canPresent()) return;

    _presenting = true;
    try {
      toastification.show(
        autoCloseDuration: const Duration(seconds: 4),
        closeOnClick: true,
        pauseOnHover: true,
        type: ToastificationType.success,
        style: ToastificationStyle.minimal,
        showProgressBar: true,
        primaryColor: AppColors.green2,
        title: Text(
          notice.message,
          style: const TextStyle(color: AppColors.headlineColor, fontWeight: FontWeight.w700),
        ),
      );
    } finally {
      _presenting = false;
    }
  }
}
