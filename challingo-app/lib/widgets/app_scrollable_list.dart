import 'package:flutter/material.dart';

/// Programmatic scrolling for an [AppScrollableList]: jump or animate to an
/// item index, with an [alignment] within the viewport (0 = leading edge,
/// 0.5 = center, 1 = trailing edge).
class AppScrollableListController {
  _AppScrollableListState? _state;

  final ScrollController scrollController = ScrollController();

  bool get isAttached => _state != null;

  /// Animates to [index]. Works with variable-height items: first moves near
  /// the estimated offset, then fine-tunes once the item is actually built.
  Future<void> scrollToIndex(
    int index, {
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) async {
    final state = _state;
    if (state == null) return;
    await state._scrollToIndex(index, alignment: alignment, duration: duration, curve: curve);
  }

  /// Jumps to [index] without animation.
  void jumpToIndex(int index, {double alignment = 0}) {
    _state?._scrollToIndex(index, alignment: alignment, duration: Duration.zero, curve: Curves.linear);
  }

  void dispose() {
    scrollController.dispose();
  }
}

/// First-party replacement for the previously vendored
/// `scrollable_positioned_list`: a [ListView.builder] with scroll-to-index
/// support via [AppScrollableListController] and [initialScrollIndex].
///
/// Index targeting is exact when [itemExtent] is provided; otherwise the
/// controller estimates the offset from the laid-out items and fine-tunes
/// with [Scrollable.ensureVisible] once the target is built.
class AppScrollableList extends StatefulWidget {
  const AppScrollableList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.controller,
    this.initialScrollIndex,
    this.itemExtent,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final AppScrollableListController? controller;

  /// Item shown at the top on first layout (like
  /// `ScrollablePositionedList.initialScrollIndex`).
  final int? initialScrollIndex;

  /// Fixed main-axis extent per item; makes index math exact.
  final double? itemExtent;

  final Axis scrollDirection;
  final bool reverse;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  @override
  State<AppScrollableList> createState() => _AppScrollableListState();
}

class _AppScrollableListState extends State<AppScrollableList> {
  final Map<int, GlobalKey> _itemKeys = {};
  AppScrollableListController? _ownController;

  AppScrollableListController get _controller =>
      widget.controller ?? (_ownController ??= AppScrollableListController());

  ScrollController get _scrollController => _controller.scrollController;

  @override
  void initState() {
    super.initState();
    _controller._state = this;
    final initial = widget.initialScrollIndex;
    if (initial != null && initial > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.jumpToIndex(initial);
      });
    }
  }

  @override
  void didUpdateWidget(covariant AppScrollableList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      _controller._state = this;
    }
    if (oldWidget.itemCount != widget.itemCount) {
      _itemKeys.removeWhere((index, _) => index >= widget.itemCount);
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _ownController?.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int index) => _itemKeys.putIfAbsent(index, GlobalKey.new);

  Future<void> _scrollToIndex(
    int index, {
    required double alignment,
    required Duration duration,
    required Curve curve,
  }) async {
    if (!_scrollController.hasClients || widget.itemCount == 0) return;
    final target = index.clamp(0, widget.itemCount - 1);

    // Exact offset when every item has a fixed extent.
    final extent = widget.itemExtent;
    if (extent != null) {
      final position = _scrollController.position;
      final viewport = position.viewportDimension;
      final offset = (target * extent - (viewport - extent) * alignment)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      await _moveTo(offset, duration, curve);
      return;
    }

    // Variable extents: approach the estimated offset until the item is
    // built, then let ensureVisible align it precisely.
    for (var attempt = 0; attempt < 8; attempt++) {
      final itemContext = _itemKeys[target]?.currentContext;
      if (itemContext != null && itemContext.mounted) {
        await Scrollable.ensureVisible(
          itemContext,
          alignment: alignment,
          duration: duration,
          curve: curve,
        );
        return;
      }
      final position = _scrollController.position;
      final totalEstimate = position.maxScrollExtent + position.viewportDimension;
      final estimatedExtent = totalEstimate / widget.itemCount;
      final offset = (target * estimatedExtent)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      await _moveTo(offset, duration, curve);
      // Let the frame build the newly revealed items before re-checking.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
  }

  Future<void> _moveTo(double offset, Duration duration, Curve curve) async {
    if (duration == Duration.zero) {
      _scrollController.jumpTo(offset);
    } else {
      await _scrollController.animateTo(offset, duration: duration, curve: curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buildItem(BuildContext context, int index) =>
        KeyedSubtree(key: _keyFor(index), child: widget.itemBuilder(context, index));

    if (widget.separatorBuilder != null) {
      return ListView.separated(
        controller: _scrollController,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        padding: widget.padding,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        itemCount: widget.itemCount,
        itemBuilder: buildItem,
        separatorBuilder: widget.separatorBuilder!,
      );
    }
    return ListView.builder(
      controller: _scrollController,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      padding: widget.padding,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      itemCount: widget.itemCount,
      itemExtent: widget.itemExtent,
      itemBuilder: buildItem,
    );
  }
}
