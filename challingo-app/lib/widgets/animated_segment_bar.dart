import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

const _segmentTileHorizontalPadding = 6.0;
const _fieldLabelGap = 6.0;
const _fieldLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: AppColors.subheadColor,
  height: 1.2,
);

/// One selectable entry of an [AnimatedSegmentBar]: a [value], its [label],
/// and an optional leading [icon].
class SegmentItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const SegmentItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Pill-style segment control with a sliding selection indicator.
class AnimatedSegmentBar<T> extends StatefulWidget {
  final T value;
  final List<SegmentItem<T>> items;
  final ValueChanged<T> onChanged;
  final double height;
  final Duration duration;
  final Curve curve;
  final bool scrollable;
  final double minSegmentWidth;

  const AnimatedSegmentBar({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.height = 36,
    this.duration = const Duration(milliseconds: 160),
    this.curve = Curves.easeOut,
    this.scrollable = false,
    this.minSegmentWidth = 92,
  }) : assert(items.length >= 2, 'AnimatedSegmentBar requires at least two items.');

  @override
  State<AnimatedSegmentBar<T>> createState() => _AnimatedSegmentBarState<T>();
}

/// [AnimatedSegmentBar] with a small field label above it — matches form field chrome.
class SegmentField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<SegmentItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool scrollable;
  final double height;

  const SegmentField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.scrollable = false,
    this.height = 36,
  });

  static double minHeightFor({double barHeight = 36}) {
    final labelPainter = TextPainter(
      text: const TextSpan(text: 'Ag', style: _fieldLabelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return labelPainter.height + _fieldLabelGap + barHeight;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expandHorizontally = constraints.maxWidth.isFinite;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: expandHorizontally ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          children: [
            Text(label, style: _fieldLabelStyle),
            const SizedBox(height: _fieldLabelGap),
            AnimatedSegmentBar<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              height: height,
              scrollable: scrollable || items.length > 4,
              minSegmentWidth: 96,
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedSegmentBarState<T> extends State<AnimatedSegmentBar<T>> {
  static const _trackPadding = 3.0;
  static const _indicatorInset = 2.0;
  static const _labelStyle = TextStyle(
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w800,
  );

  int get _selectedIndex {
    final index = widget.items.indexWhere((item) => item.value == widget.value);
    return index < 0 ? 0 : index;
  }

  double _minWidthForItem(SegmentItem<T> item, TextDirection textDirection) {
    final painter = TextPainter(
      text: TextSpan(text: item.label, style: _labelStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();

    var width = painter.width + (_segmentTileHorizontalPadding * 2);
    if (item.icon != null) {
      width += 14 + 4;
    }
    return width.ceilToDouble();
  }

  List<double> _intrinsicSegmentWidths(TextDirection textDirection) {
    return widget.items
        .map((item) => math.max(_minWidthForItem(item, textDirection), widget.minSegmentWidth))
        .toList(growable: false);
  }

  List<double> _segmentWidths({
    required double innerWidth,
    required TextDirection textDirection,
  }) {
    final contentMins = widget.items
        .map((item) => _minWidthForItem(item, textDirection))
        .toList(growable: false);
    final equalWidth = innerWidth / widget.items.length;
    final needsScroll = contentMins.any((width) => width > equalWidth) ||
        (widget.scrollable && innerWidth < widget.items.length * widget.minSegmentWidth);

    if (needsScroll) {
      return contentMins
          .map((width) => math.max(width, widget.minSegmentWidth))
          .toList(growable: false);
    }
    return List<double>.filled(widget.items.length, equalWidth);
  }

  double _offsetForIndex(List<double> segmentWidths, int index) {
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      offset += segmentWidths[i];
    }
    return offset;
  }

  double _contentWidth(List<double> segmentWidths) {
    return segmentWidths.fold<double>(0, (sum, width) => sum + width);
  }

  Widget _buildTrack({
    required List<double> segmentWidths,
    required double trackWidth,
  }) {
    final indicatorLeft = _offsetForIndex(segmentWidths, _selectedIndex) + _indicatorInset;
    final indicatorWidth = segmentWidths[_selectedIndex] - (_indicatorInset * 2);

    return SizedBox(
      width: trackWidth,
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xfff1f5f9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_trackPadding),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedPositioned(
                  duration: widget.duration,
                  curve: widget.curve,
                  left: indicatorLeft,
                  width: indicatorWidth,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < widget.items.length; i++)
                      SizedBox(
                        width: segmentWidths[i],
                        child: _SegmentTile<T>(
                          item: widget.items[i],
                          selected: i == _selectedIndex,
                          duration: widget.duration,
                          curve: widget.curve,
                          onTap: () {
                            if (widget.items[i].value != widget.value) {
                              widget.onChanged(widget.items[i].value);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth = constraints.maxWidth.isFinite;
        final viewportWidth = hasBoundedWidth ? constraints.maxWidth : null;
        final innerWidth = viewportWidth == null ? null : math.max(0.0, viewportWidth - (_trackPadding * 2));

        final segmentWidths = innerWidth == null
            ? _intrinsicSegmentWidths(textDirection)
            : _segmentWidths(innerWidth: innerWidth, textDirection: textDirection);

        final contentWidth = _contentWidth(segmentWidths);
        final useScroll = innerWidth != null && contentWidth > innerWidth + 0.5;
        final trackWidth = useScroll
            ? contentWidth + (_trackPadding * 2)
            : (viewportWidth ?? contentWidth + (_trackPadding * 2));

        final track = _buildTrack(segmentWidths: segmentWidths, trackWidth: trackWidth);

        if (useScroll) {
          return SizedBox(
            height: widget.height,
            width: viewportWidth,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: track,
            ),
          );
        }

        if (hasBoundedWidth) {
          return SizedBox(height: widget.height, child: track);
        }

        return track;
      },
    );
  }
}

class _SegmentTile<T> extends StatelessWidget {
  final SegmentItem<T> item;
  final bool selected;
  final Duration duration;
  final Curve curve;
  final VoidCallback onTap;

  const _SegmentTile({
    required this.item,
    required this.selected,
    required this.duration,
    required this.curve,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primaryColor;
    final idleColor = AppColors.subheadColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _segmentTileHorizontalPadding),
            child: AnimatedDefaultTextStyle(
              duration: duration,
              curve: curve,
              style: TextStyle(
                fontSize: 11,
                height: 1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? activeColor : idleColor,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.icon != null) ...[
                    Icon(
                      item.icon,
                      size: 14,
                      color: selected ? activeColor : idleColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
