import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../../di.dart';
import '../extensions/context_extension.dart';
import '../helpers/failure_localizer.dart';
import '../helpers/logger_service.dart';
import '../interfaces/base_failure.dart';
import '../interfaces/base_overlays_helper.dart';
import '../interfaces/base_result.dart';
import '../navigation/app_routes.dart';
import '../../widgets/overlays/token_expire_overlay.dart';

abstract class FailurePresenter {
  static BuildContext? get _rootContext => AppRoutes.rootContext;

  static bool _presenting = false;

  /// Schedules UI feedback after the current frame so we never call
  /// [ScaffoldMessenger] / [toastification] during build (visitChildElements assert).
  static void show(FailureNotice n) {
    if (_shouldIgnoreNotice(n)) return;

    if (n.failure is UnAuthenticateFailure) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_canPresent()) return;
        _showTokenExpired();
      });
      return;
    }

    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      if (!_canPresent()) return;
      _presentNow(n);
    });
  }

  static Future<void> _showTokenExpired() async {
    if (_presenting || !_canPresent()) return;
    _presenting = true;
    try {
      final overlayHelper = locator<BaseOverlaysHelper>();
      if (overlayHelper.alertKey.currentContext != null &&
          overlayHelper.alertKey.currentContext?.mounted == true) {
        return;
      }
      await overlayHelper.showAppDialog<bool?>(
        (_) => const TokenExpireOverlay(),
        barrierDismissible: false,
      );
    } finally {
      _presenting = false;
    }
  }

  static bool _shouldIgnoreNotice(FailureNotice n) {
    final msg = n.failure.message;
    return msg.contains('visitChildElements() called during build') ||
        msg.contains('Cannot fire new event') ||
        msg.contains('Controller is already firing an event');
  }

  static bool _canPresent() {
    final context = _rootContext;
    return context != null && context.mounted;
  }

  static void _presentNow(FailureNotice n) {
    if (_presenting || _shouldIgnoreNotice(n) || !_canPresent()) return;

    _presenting = true;
    try {
      final failure = n.failure;
      appLog.e('Presenting ${failure.runtimeType}: ${failure.message}');
      if (n.extra is Error) {
        appLog.e('FailureNotice.extra: ${n.extra}');
      }
      switch (n.severity) {
        case FailureSeverity.info:
          _showSnack(n, bg: Colors.blueAccent);
          break;
        case FailureSeverity.warning:
          _showSnack(n, bg: Colors.orangeAccent);
          break;
        case FailureSeverity.error:
          _showToast(n);
          break;
        case FailureSeverity.critical:
          _showDialog(n);
          break;
      }
    } finally {
      _presenting = false;
    }
  }

  static void _showSnack(FailureNotice n, {required Color bg}) {
    final context = _rootContext;
    if (context == null || !context.mounted) {
      appLog.e('No context found for snackbar');
      return;
    }
    final l10n = context.localizations;
    final text = FailureLocalizer.localize(l10n, n.failure);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
          duration: const Duration(seconds: 6),
          content: Text(text),
          action: n.retry == null
              ? null
              : SnackBarAction(
                  label: l10n.retry,
                  textColor: Colors.white,
                  onPressed: n.retry!,
                ),
        ),
      );
  }

  static void _showToast(FailureNotice n) {
    final context = _rootContext;
    final text = context == null || !context.mounted
        ? n.failure.message
        : FailureLocalizer.localize(context.localizations, n.failure);
    toastification.dismissAll();
    toastification.show(
      autoCloseDuration: const Duration(seconds: 6),
      closeOnClick: true,
      pauseOnHover: true,
      type: ToastificationType.error,
      style: ToastificationStyle.minimal,
      showProgressBar: true,
      title: Text(text),
    );
  }

  static void _showDialog(FailureNotice n) {
    final context = _rootContext;
    if (context == null || !context.mounted) {
      appLog.e('No context found for dialog');
      return;
    }
    final l10n = context.localizations;
    final text = FailureLocalizer.localize(l10n, n.failure);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: Text(l10n.errorTitle),
        content: Text(text),
        actions: [
          if (n.retry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).maybePop();
                n.retry?.call();
              },
              child: Text(l10n.retry),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
