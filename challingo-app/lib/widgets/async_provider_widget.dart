import 'dart:async';

import '/core/extensions/context_extension.dart';
import '/widgets/buttons/app_button.dart';
import '/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show ProviderListenable, ProviderOrFamily;

/// Standard async UI wrapper for Riverpod providers.
///
/// Inline mode (default): spinner while loading, error + retry, then content.
/// Modal mode ([useLoadingModal]): dims the screen with a barrier + loader and
/// keeps it visible at least [loadingModalMinDuration] so fast responses do
/// not flash, then cross-fades to content.
class AsyncProviderWidget<T> extends ConsumerStatefulWidget {
  const AsyncProviderWidget({
    super.key,
    required this.provider,
    required this.builder,
    this.loadingWidget,
    this.loadingBuilder,
    this.errorBuilder,
    this.useLoadingModal = false,
    this.loadingModalWidget,
    this.loadingModalBarrierColor = const Color(0x99000000),
    this.loadingModalMinDuration = const Duration(milliseconds: 450),
    this.loadingModalFadeDuration = const Duration(milliseconds: 280),
  });

  final ProviderListenable<AsyncValue<T>> provider;
  final Widget Function(T? value) builder;
  final Widget? loadingWidget;
  final Widget Function()? loadingBuilder;
  final Widget Function(Object error, StackTrace stackTrace)? errorBuilder;
  final bool useLoadingModal;
  final Widget? loadingModalWidget;
  final Color loadingModalBarrierColor;

  /// Keeps the loading modal visible at least this long so fast responses do
  /// not flash before route / fade transitions finish.
  final Duration loadingModalMinDuration;

  /// Fade between loading modal and loaded content.
  final Duration loadingModalFadeDuration;

  @override
  ConsumerState<AsyncProviderWidget<T>> createState() => _AsyncProviderWidgetState<T>();
}

class _AsyncProviderWidgetState<T> extends ConsumerState<AsyncProviderWidget<T>> {
  DateTime? _loadingStartedAt;
  bool _deferContent = false;
  Timer? _releaseTimer;

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  void _resetLoadingModalState() {
    _releaseTimer?.cancel();
    _loadingStartedAt = null;
    if (_deferContent) {
      setState(() => _deferContent = false);
    }
  }

  void _onProviderUpdate(AsyncValue<T>? previous, AsyncValue<T> next) {
    if (!widget.useLoadingModal) return;

    final wasInitialLoading = previous != null && previous.isLoading && !previous.hasValue;
    final isInitialLoading = next.isLoading && !next.hasValue;

    if (isInitialLoading) {
      _loadingStartedAt ??= DateTime.now();
      return;
    }

    if (next.hasError) {
      _resetLoadingModalState();
      return;
    }

    if (wasInitialLoading && next.hasValue) {
      final started = _loadingStartedAt ?? DateTime.now();
      final elapsed = DateTime.now().difference(started);
      final remaining = widget.loadingModalMinDuration - elapsed;

      if (remaining <= Duration.zero) {
        _resetLoadingModalState();
        return;
      }

      _releaseTimer?.cancel();
      if (!_deferContent) {
        setState(() => _deferContent = true);
      }
      _releaseTimer = Timer(remaining, () {
        if (!mounted) return;
        setState(() {
          _deferContent = false;
          _loadingStartedAt = null;
        });
      });
    }
  }

  bool _showLoadingModal(AsyncValue<T> asyncValue) {
    if (!widget.useLoadingModal) return false;
    if (asyncValue.isLoading && !asyncValue.hasValue) return true;
    return _deferContent;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<T>>(widget.provider, _onProviderUpdate);

    final asyncValue = ref.watch(widget.provider);

    if (widget.useLoadingModal && asyncValue.isLoading && !asyncValue.hasValue) {
      _loadingStartedAt ??= DateTime.now();
    }

    if (widget.useLoadingModal) {
      final content = _buildModalContent(context, asyncValue);
      return AnimatedSwitcher(
        duration: widget.loadingModalFadeDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _showLoadingModal(asyncValue)
            ? ColoredBox(
                key: const ValueKey('async_provider_loading_modal'),
                color: widget.loadingModalBarrierColor,
                child: Center(
                  child: widget.loadingModalWidget ?? const LoadingWidget(),
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('async_provider_content'),
                child: content,
              ),
      );
    }

    return _buildInlineContent(context, asyncValue);
  }

  Widget _buildModalContent(BuildContext context, AsyncValue<T> asyncValue) {
    if (asyncValue.hasValue) {
      return widget.builder(asyncValue.value);
    }

    return switch (asyncValue) {
      AsyncLoading() => widget.loadingBuilder?.call() ?? const SizedBox.shrink(),
      AsyncError(:final error, :final stackTrace) =>
        widget.errorBuilder?.call(error, stackTrace) ?? _defaultError(context, error),
      AsyncData(:final value) => widget.builder(value),
    };
  }

  Widget _buildInlineContent(BuildContext context, AsyncValue<T> asyncValue) {
    if (asyncValue.isRefreshing || asyncValue.isReloading) {
      return _inlineLoading(context);
    }

    return switch (asyncValue) {
      AsyncData(:final value) => widget.builder(value),
      AsyncLoading() => _inlineLoading(context),
      AsyncError(:final error, :final stackTrace) =>
        widget.errorBuilder?.call(error, stackTrace) ?? _defaultError(context, error),
    };
  }

  Widget _inlineLoading(BuildContext context) {
    return widget.loadingWidget ?? LoadingWidget(size: 40, color: context.mainColor);
  }

  Widget _defaultError(BuildContext context, Object error) {
    final l10n = context.localizations;
    return Center(
      child: Column(
        spacing: 12,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$error',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppButton(
                height: 30,
                color: Colors.orange,
                label: l10n.retry,
                onPressed: () {
                  ref.invalidate(widget.provider as ProviderOrFamily);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
