import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

const double _kToolbarTopInset = 12;

/// Per-section visuals for [CollapsingHeroAppBar].
class CollapsingHeroSectionDecorations {
  const CollapsingHeroSectionDecorations({
    this.upperCollapsed,
    this.upperCollapsedBlurSigma,
    this.middle,
    this.middleBlurSigma,
    this.bottom,
    this.bottomBlurSigma,
  });

  /// Upper toolbar background when header is collapsed (fades in on scroll).
  final Decoration? upperCollapsed;
  final double? upperCollapsedBlurSigma;

  /// Optional overlay on the middle/image area while expanded.
  final Decoration? middle;
  final double? middleBlurSigma;

  /// Bottom titles area — e.g. frosted glass via [bottomBlurSigma].
  final Decoration? bottom;
  final double? bottomBlurSigma;

  /// Frosted bottom section preset.
  static CollapsingHeroSectionDecorations frostedBottom({
    double blurSigma = 12,
    Color tint = const Color.fromRGBO(255, 255, 255, 0.06),
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
    return CollapsingHeroSectionDecorations(
      bottomBlurSigma: blurSigma,
      bottom: BoxDecoration(
        color: tint,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Layout + typography for [CollapsingHeroAppBar].
class CollapsingHeroAppBarStyle {
  const CollapsingHeroAppBarStyle({
    this.upperSectionHeight = 78,
    this.middleImageHeight = 280,
    this.bottomSectionMinHeight = 96,
    this.horizontalPadding = 16,
    this.bottomPadding = 16,
    this.titleSpacing = 4,
    this.toolbarIconSize = 56,
    this.toolbarIconGlyphSize,
    this.toolbarBottomPadding = 12,
    this.toolbarSpacing = 12,
    this.collapsedTitleStyle,
    this.expandedTitleStyle,
    this.expandedFooterStyle,
    this.sectionDecorations = const CollapsingHeroSectionDecorations(),
    this.collapsedBackgroundColor,
    this.bottomGradientColors = const [
      Color.fromRGBO(0, 0, 0, 0.75),
      Color.fromRGBO(0, 0, 0, 0),
    ],
    this.pinned = true,
  });

  final double upperSectionHeight;
  final double middleImageHeight;
  final double bottomSectionMinHeight;
  final double horizontalPadding;
  final double bottomPadding;
  final double titleSpacing;
  final double toolbarIconSize;
  final double? toolbarIconGlyphSize;
  final double toolbarBottomPadding;
  final double toolbarSpacing;
  final TextStyle? collapsedTitleStyle;
  final TextStyle? expandedTitleStyle;
  final TextStyle? expandedFooterStyle;
  final CollapsingHeroSectionDecorations sectionDecorations;

  /// Fills the header as the hero image fades out. Defaults to [sectionDecorations.upperCollapsed] color.
  final Color? collapsedBackgroundColor;
  final List<Color> bottomGradientColors;
  final bool pinned;

  Color resolveCollapsedBackgroundColor(BuildContext context) {
    if (collapsedBackgroundColor != null) return collapsedBackgroundColor!;
    final fromDecoration = _colorFromDecoration(sectionDecorations.upperCollapsed);
    if (fromDecoration != null) return fromDecoration;
    return Theme.of(context).colorScheme.surface;
  }

  double collapsedHeight(BuildContext context) => toolbarExtent(_kToolbarTopInset);

  double toolbarExtent(double topInset) =>
      topInset + upperSectionHeight + horizontalPadding;

  double expandedHeight(BuildContext context) => expandedHeightFor(context, bottomSectionMinHeight);

  /// Scroll fraction [0–1] where middle collapse finishes and bottom collapse begins.
  double middleCollapseEndsAtFor(double bottomSectionHeight) {
    final total = middleImageHeight + bottomSectionHeight;
    if (total <= 0) return 1;
    return middleImageHeight / total;
  }

  double expandedHeightFor(BuildContext context, double bottomSectionHeight) =>
      collapsedHeight(context) + middleImageHeight + bottomSectionHeight;

  /// Default hero header preset — used when [CollapsingHeroAppBar] has no custom style.
  static CollapsingHeroAppBarStyle get standard => CollapsingHeroAppBarStyle(
        middleImageHeight: 96,
        upperSectionHeight: 52,
        toolbarIconSize: 44,
        toolbarIconGlyphSize: 20,
        toolbarSpacing: 8,
        bottomSectionMinHeight: 140,
        expandedTitleStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        collapsedTitleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        expandedFooterStyle: const TextStyle(
          fontSize: 16,
          color: Colors.white70,
        ),
        sectionDecorations: CollapsingHeroSectionDecorations(
          upperCollapsed: BoxDecoration(
            color: AppColors.black2.withValues(alpha: 0.92),
          ),
          upperCollapsedBlurSigma: 3,
          bottom: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
          bottomBlurSigma: 3,
        ),
      );
}

Color? _colorFromDecoration(Decoration? decoration) {
  if (decoration is BoxDecoration) {
    return decoration.color;
  }
  return null;
}

class _PhasedSectionHeights {
  const _PhasedSectionHeights({
    required this.middleHeight,
    required this.bottomHeight,
    required this.inMiddlePhase,
    required this.inBottomPhase,
    required this.bottomPhaseProgress,
    required this.showBottomContent,
  });

  final double middleHeight;
  final double bottomHeight;
  final bool inMiddlePhase;
  final bool inBottomPhase;
  final double bottomPhaseProgress;

  /// Bottom titles + glass — only while middle is collapsing (jumps away after).
  final bool showBottomContent;

  static _PhasedSectionHeights fromLayout({
    required CollapsingHeroAppBarStyle style,
    required double progress,
    required double contentHeight,
    required double bottomSectionHeight,
  }) {
    final middleEnd = style.middleCollapseEndsAtFor(bottomSectionHeight);
    final p = progress.clamp(0.0, 1.0);
    final safeContent = contentHeight.clamp(0.0, double.infinity);

    if (p <= middleEnd) {
      final t = middleEnd <= 0 ? 1.0 : p / middleEnd;
      final middle = (style.middleImageHeight * (1 - t)).clamp(0.0, safeContent);
      final bottom = (safeContent - middle).clamp(0.0, safeContent);
      return _PhasedSectionHeights(
        middleHeight: middle,
        bottomHeight: bottom,
        inMiddlePhase: true,
        inBottomPhase: false,
        bottomPhaseProgress: 0,
        showBottomContent: true,
      );
    }

    final bottomSpan = 1 - middleEnd;
    final bottomT = bottomSpan <= 0 ? 1.0 : ((p - middleEnd) / bottomSpan).clamp(0.0, 1.0);
    return _PhasedSectionHeights(
      middleHeight: 0,
      bottomHeight: safeContent,
      inMiddlePhase: false,
      inBottomPhase: true,
      bottomPhaseProgress: bottomT,
      showBottomContent: false,
    );
  }
}

/// Posted when the expanded bottom title section measures taller than the preset minimum.
class CollapsingHeroBottomSectionMeasuredNotification extends Notification {
  const CollapsingHeroBottomSectionMeasuredNotification(this.height);

  final double height;
}

/// Collapsing header: upper toolbar, middle image, bottom titles that move into the toolbar on scroll.
class CollapsingHeroAppBar extends StatelessWidget {
  CollapsingHeroAppBar({
    super.key,
    required this.title,
    CollapsingHeroAppBarStyle? style,
    this.leading,
    this.actions = const [],
    this.background,
    this.titleHeader,
    this.titleFooter,
    this.foregroundColor = Colors.white,
    this.bottomSectionMeasureKey,
  }) : style = style ?? CollapsingHeroAppBarStyle.standard;

  final String title;
  final CollapsingHeroAppBarStyle style;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? background;
  final Widget? titleHeader;
  final Widget? titleFooter;
  final Color foregroundColor;

  /// When this value changes, [CollapsingHeroScrollView] remeasures the bottom section.
  final Object? bottomSectionMeasureKey;

  double expandedHeight(BuildContext context, {double? bottomSectionHeight}) =>
      style.expandedHeightFor(
        context,
        bottomSectionHeight ?? style.bottomSectionMinHeight,
      );

  double collapsedHeight(BuildContext context) => style.collapsedHeight(context);

  /// Use inside [CustomScrollView.slivers].
  Widget buildSliver(
    BuildContext context, {
    double? bottomSectionHeight,
  }) {
    final resolvedBottomHeight = bottomSectionHeight ?? style.bottomSectionMinHeight;
    final expanded = expandedHeight(context, bottomSectionHeight: resolvedBottomHeight);

    return SliverPersistentHeader(
      pinned: style.pinned,
      delegate: _CollapsingHeroAppBarDelegate(
        expandedHeight: expanded,
        collapsedHeight: collapsedHeight(context),
        bottomSectionHeight: resolvedBottomHeight,
        style: style,
        title: title,
        leading: leading,
        actions: actions,
        background: background,
        titleHeader: titleHeader,
        titleFooter: titleFooter,
        foregroundColor: foregroundColor,
        bottomSectionMeasureKey: bottomSectionMeasureKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: expandedHeight(context),
      child: _CollapsingHeroAppBarBody(
        progress: 0,
        currentHeight: expandedHeight(context),
        bottomSectionHeight: style.bottomSectionMinHeight,
        style: style,
        title: title,
        leading: leading,
        actions: actions,
        background: background,
        titleHeader: titleHeader,
        titleFooter: titleFooter,
        foregroundColor: foregroundColor,
        bottomSectionMeasureKey: bottomSectionMeasureKey,
      ),
    );
  }
}

/// [CustomScrollView] wrapper — pass the same [scrollController] you use elsewhere.
class CollapsingHeroScrollView extends StatefulWidget {
  const CollapsingHeroScrollView({
    super.key,
    required this.appBar,
    required this.slivers,
    this.scrollController,
    this.physics,
    this.backgroundColor,
  });

  final CollapsingHeroAppBar appBar;
  final List<Widget> slivers;
  final ScrollController? scrollController;
  final ScrollPhysics? physics;

  /// Opaque fill behind the scroll view so route transitions do not show the
  /// previous page through transparent viewport areas.
  final Color? backgroundColor;

  @override
  State<CollapsingHeroScrollView> createState() => _CollapsingHeroScrollViewState();
}

class _CollapsingHeroScrollViewState extends State<CollapsingHeroScrollView> {
  late double _bottomSectionHeight = widget.appBar.style.bottomSectionMinHeight;

  @override
  void didUpdateWidget(covariant CollapsingHeroScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Footer/header widgets are new instances on every parent rebuild — only
    // reset measured height when title or measure key changes.
    if (oldWidget.appBar.title != widget.appBar.title ||
        oldWidget.appBar.bottomSectionMeasureKey !=
            widget.appBar.bottomSectionMeasureKey) {
      _bottomSectionHeight = widget.appBar.style.bottomSectionMinHeight;
    }
  }

  bool _onBottomSectionMeasured(CollapsingHeroBottomSectionMeasuredNotification notification) {
    final resolved = notification.height.clamp(
      widget.appBar.style.bottomSectionMinHeight,
      double.infinity,
    );
    // Only grow — avoids shrinking back to min between rebuild frames.
    if (resolved > _bottomSectionHeight + 0.5) {
      setState(() => _bottomSectionHeight = resolved);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: bg),
        NotificationListener<CollapsingHeroBottomSectionMeasuredNotification>(
          onNotification: _onBottomSectionMeasured,
          child: CustomScrollView(
            controller: widget.scrollController,
            physics: widget.physics ??
                CollapsingHeroSnapScrollPhysics.forAppBar(
                  widget.appBar,
                  bottomSectionHeight: _bottomSectionHeight,
                ),
            slivers: [
              widget.appBar.buildSliver(
                context,
                bottomSectionHeight: _bottomSectionHeight,
              ),
              ...widget.slivers,
            ],
          ),
        ),
      ],
    );
  }
}

/// Snaps header to expanded / middle-gone / collapsed when scroll settles near a phase boundary.
class CollapsingHeroSnapScrollPhysics extends ScrollPhysics {
  const CollapsingHeroSnapScrollPhysics({
    required this.snapOffsets,
    this.snapThreshold = 28,
    super.parent,
  });

  final List<double> snapOffsets;
  final double snapThreshold;

  factory CollapsingHeroSnapScrollPhysics.forAppBar(
    CollapsingHeroAppBar appBar, {
    double? bottomSectionHeight,
    ScrollPhysics? parent,
    double snapThreshold = 28,
  }) {
    final style = appBar.style;
    final resolvedBottomHeight = bottomSectionHeight ?? style.bottomSectionMinHeight;
    return CollapsingHeroSnapScrollPhysics(
      snapThreshold: snapThreshold,
      snapOffsets: [
        0,
        style.middleImageHeight,
        style.middleImageHeight + resolvedBottomHeight,
      ],
      parent: parent ?? const BouncingScrollPhysics(),
    );
  }

  @override
  CollapsingHeroSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CollapsingHeroSnapScrollPhysics(
      snapOffsets: snapOffsets,
      snapThreshold: snapThreshold,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);
    if (velocity.abs() >= tolerance.velocity) {
      return super.createBallisticSimulation(position, velocity);
    }

    final offset = position.pixels;

    // Overscroll (pull-down bounce): return to top without phase snapping.
    if (offset < 0) {
      return ScrollSpringSimulation(
        spring,
        offset,
        0,
        velocity,
        tolerance: tolerance,
      );
    }

    double? nearestSnap;
    var nearestDistance = double.infinity;
    for (final snap in snapOffsets) {
      final distance = (offset - snap).abs();
      if (distance < nearestDistance && distance <= snapThreshold) {
        nearestDistance = distance;
        nearestSnap = snap;
      }
    }

    if (nearestSnap != null) {
      return ScrollSpringSimulation(
        spring,
        offset,
        nearestSnap,
        velocity,
        tolerance: tolerance,
      );
    }

    return super.createBallisticSimulation(position, velocity);
  }
}

class _CollapsingHeroAppBarDelegate extends SliverPersistentHeaderDelegate {
  _CollapsingHeroAppBarDelegate({
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.bottomSectionHeight,
    required this.style,
    required this.title,
    required this.leading,
    required this.actions,
    required this.background,
    required this.titleHeader,
    required this.titleFooter,
    required this.foregroundColor,
    this.bottomSectionMeasureKey,
  });

  final double expandedHeight;
  final double collapsedHeight;
  final double bottomSectionHeight;
  final CollapsingHeroAppBarStyle style;
  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? background;
  final Widget? titleHeader;
  final Widget? titleFooter;
  final Color foregroundColor;
  final Object? bottomSectionMeasureKey;

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final collapseRange = maxExtent - minExtent;
    final progress = collapseRange <= 0 ? 1.0 : (shrinkOffset / collapseRange).clamp(0.0, 1.0);
    final currentHeight = (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);

    return SizedBox(
      height: currentHeight,
      child: _CollapsingHeroAppBarBody(
        progress: progress,
        currentHeight: currentHeight,
        bottomSectionHeight: bottomSectionHeight,
        style: style,
        title: title,
        leading: leading,
        actions: actions,
        background: background,
        titleHeader: titleHeader,
        titleFooter: titleFooter,
        foregroundColor: foregroundColor,
        bottomSectionMeasureKey: bottomSectionMeasureKey,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CollapsingHeroAppBarDelegate oldDelegate) {
    return oldDelegate.expandedHeight != expandedHeight ||
        oldDelegate.collapsedHeight != collapsedHeight ||
        oldDelegate.bottomSectionHeight != bottomSectionHeight ||
        oldDelegate.title != title ||
        oldDelegate.style != style ||
        oldDelegate.leading != leading ||
        oldDelegate.actions != actions ||
        oldDelegate.background != background ||
        oldDelegate.titleHeader != titleHeader ||
        oldDelegate.titleFooter != titleFooter ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.bottomSectionMeasureKey != bottomSectionMeasureKey;
  }
}

class _CollapsingHeroAppBarBody extends StatelessWidget {
  const _CollapsingHeroAppBarBody({
    required this.progress,
    required this.currentHeight,
    required this.bottomSectionHeight,
    required this.style,
    required this.title,
    required this.leading,
    required this.actions,
    required this.background,
    required this.titleHeader,
    required this.titleFooter,
    required this.foregroundColor,
    this.bottomSectionMeasureKey,
  });

  final double progress;
  final double currentHeight;
  final double bottomSectionHeight;
  final CollapsingHeroAppBarStyle style;
  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? background;
  final Widget? titleHeader;
  final Widget? titleFooter;
  final Color foregroundColor;
  final Object? bottomSectionMeasureKey;

  Decoration _defaultBottomDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: style.bottomGradientColors,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const topInset = _kToolbarTopInset;
    final toolbarHeight = style.toolbarExtent(topInset);
    final contentHeight = (currentHeight - toolbarHeight).clamp(0.0, double.infinity);
    final phases = _PhasedSectionHeights.fromLayout(
      style: style,
      progress: progress,
      contentHeight: contentHeight,
      bottomSectionHeight: bottomSectionHeight,
    );
    final isFullyExpanded = progress <= 0.001;
    final middleHeight = phases.middleHeight;
    final bottomHeight = phases.bottomHeight;
    final collapsedTitleOpacity = phases.inBottomPhase
        ? Curves.easeOut.transform(phases.bottomPhaseProgress)
        : 0.0;

    final expandedTitleStyle = style.expandedTitleStyle ??
        Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ) ??
        TextStyle(color: foregroundColor, fontSize: 24, fontWeight: FontWeight.w600);
    final collapsedTitleStyle = style.collapsedTitleStyle ??
        Theme.of(context).textTheme.titleMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ) ??
        TextStyle(color: foregroundColor, fontSize: 16, fontWeight: FontWeight.w600);
    final footerStyle = style.expandedFooterStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foregroundColor.withValues(alpha: 0.82),
            ) ??
        TextStyle(color: foregroundColor.withValues(alpha: 0.82), fontSize: 16);

    final textDirection = Directionality.of(context);
    final alignEnd = textDirection == TextDirection.rtl;
    final decorations = style.sectionDecorations;
    final collapsedBackgroundColor = style.resolveCollapsedBackgroundColor(context);
    final backgroundImageOpacity = phases.inMiddlePhase
        ? 1.0
        : (1 - phases.bottomPhaseProgress).clamp(0.0, 1.0);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: ColoredBox(color: collapsedBackgroundColor),
          ),
          if (background != null)
            Positioned.fill(
              child: Opacity(
                opacity: backgroundImageOpacity,
                child: _FullBleedBackground(child: background!),
              ),
            ),
          if (middleHeight > 0 && decorations.middle != null)
            Positioned(
              left: 0,
              right: 0,
              top: toolbarHeight,
              height: middleHeight,
              child: _DecoratedSection(
                decoration: decorations.middle,
                blurSigma: decorations.middleBlurSigma,
                child: const SizedBox.expand(),
              ),
            ),
          if (phases.showBottomContent && bottomHeight > 4)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomHeight,
              child: _DecoratedSection(
                decoration: decorations.bottom ?? _defaultBottomDecoration(),
                blurSigma: decorations.bottomBlurSigma,
                padding: EdgeInsets.fromLTRB(
                  style.horizontalPadding,
                  8,
                  style.horizontalPadding,
                  style.bottomPadding,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Bottom titles stay complete until middle collapse finishes
                    // (showBottomContent is false in the bottom phase).
                    return Align(
                      alignment:
                          alignEnd ? Alignment.bottomRight : Alignment.bottomLeft,
                      child: _AdaptiveTitleColumn(
                        maxHeight: constraints.maxHeight,
                        keepFullTitleContent: true,
                        titleHeader: titleHeader,
                        title: title,
                        titleFooter: titleFooter,
                        titleStyle: expandedTitleStyle,
                        footerStyle: footerStyle,
                        titleSpacing: style.titleSpacing,
                        alignEnd: alignEnd,
                      ),
                    );
                  },
                ),
              ),
            ),
          if (isFullyExpanded)
            Positioned(
              left: -10000,
              width: MediaQuery.sizeOf(context).width - (style.horizontalPadding * 2),
              bottom: 0,
              child: IgnorePointer(
                child: _MeasureSize(
                  measureToken: Object.hash(
                    title,
                    titleHeader.runtimeType,
                    titleFooter.runtimeType,
                    bottomSectionMeasureKey,
                  ),
                  onChange: (size) {
                    const measureBuffer = 8.0;
                    final totalHeight =
                        size.height + 8 + style.bottomPadding + measureBuffer;
                    CollapsingHeroBottomSectionMeasuredNotification(totalHeight)
                        .dispatch(context);
                  },
                  child: _AdaptiveTitleColumn(
                    maxHeight: double.infinity,
                    keepFullTitleContent: true,
                    titleHeader: titleHeader,
                    title: title,
                    titleFooter: titleFooter,
                    titleStyle: expandedTitleStyle,
                    footerStyle: footerStyle,
                    titleSpacing: style.titleSpacing,
                    alignEnd: alignEnd,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: toolbarHeight,
            child: Material(
              type: MaterialType.transparency,
              elevation: 0.5,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  if (decorations.upperCollapsed != null)
                    IgnorePointer(
                      child: Opacity(
                        opacity: collapsedTitleOpacity,
                        child: _DecoratedSection(
                          decoration: decorations.upperCollapsed,
                          blurSigma: decorations.upperCollapsedBlurSigma,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  _UpperToolbar(
                    leading: leading,
                    actions: actions,
                    topInset: topInset,
                    upperSectionHeight: style.upperSectionHeight,
                    horizontalPadding: style.horizontalPadding,
                    collapsedTitleOpacity: collapsedTitleOpacity,
                    title: title,
                    collapsedTitleStyle: collapsedTitleStyle,
                    alignEnd: alignEnd,
                    toolbarSpacing: style.toolbarSpacing,
                    toolbarIconSize: style.toolbarIconSize,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecoratedSection extends StatelessWidget {
  const _DecoratedSection({
    required this.child,
    this.decoration,
    this.blurSigma,
    this.padding,
  });

  final Decoration? decoration;
  final double? blurSigma;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  BorderRadius _borderRadius() {
    if (decoration is BoxDecoration) {
      final radius = (decoration as BoxDecoration).borderRadius;
      if (radius is BorderRadius) return radius;
    }
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (decoration == null && blurSigma == null) return content;

    return ClipRRect(
      borderRadius: _borderRadius(),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigma ?? 0,
          sigmaY: blurSigma ?? 0,
        ),
        child: DecoratedBox(
          decoration: decoration ?? const BoxDecoration(color: Colors.transparent),
          child: content,
        ),
      ),
    );
  }
}

class _UpperToolbar extends StatelessWidget {
  const _UpperToolbar({
    required this.leading,
    required this.actions,
    required this.topInset,
    required this.upperSectionHeight,
    required this.horizontalPadding,
    required this.toolbarSpacing,
    required this.toolbarIconSize,
    required this.collapsedTitleOpacity,
    required this.title,
    required this.collapsedTitleStyle,
    required this.alignEnd,
  });

  final Widget? leading;
  final List<Widget> actions;
  final double topInset;
  final double upperSectionHeight;
  final double horizontalPadding;
  final double toolbarSpacing;
  final double toolbarIconSize;
  final double collapsedTitleOpacity;
  final String title;
  final TextStyle collapsedTitleStyle;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final showCollapsedTitle = collapsedTitleOpacity > 0.01;

    return Padding(
      padding: EdgeInsets.only(
        top: topInset,
        bottom: horizontalPadding,
      ),
      child: SizedBox(
        height: upperSectionHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            spacing: toolbarSpacing,
            children: [
              if (leading != null) leading! else SizedBox(width: toolbarIconSize),
              Expanded(
                child: showCollapsedTitle
                    ? Opacity(
                        opacity: collapsedTitleOpacity,
                        child: ClipRect(
                          child: Align(
                            alignment: alignEnd
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Text(
                              title,
                              style: collapsedTitleStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign:
                                  alignEnd ? TextAlign.right : TextAlign.left,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays out expanded title content; scales down when space is tight instead of dropping rows early.
class _AdaptiveTitleColumn extends StatelessWidget {
  const _AdaptiveTitleColumn({
    required this.maxHeight,
    required this.keepFullTitleContent,
    required this.titleHeader,
    required this.title,
    required this.titleFooter,
    required this.titleStyle,
    required this.footerStyle,
    required this.titleSpacing,
    required this.alignEnd,
  });

  final double maxHeight;
  final bool keepFullTitleContent;
  final Widget? titleHeader;
  final String title;
  final Widget? titleFooter;
  final TextStyle titleStyle;
  final TextStyle footerStyle;
  final double titleSpacing;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final hasBoundedHeight = maxHeight.isFinite && maxHeight > 0;
    final measurePass = keepFullTitleContent && !hasBoundedHeight;

    var showFooter = titleFooter != null &&
        (keepFullTitleContent || maxHeight >= 78);
    var showHeader = titleHeader != null &&
        (keepFullTitleContent || maxHeight >= 52);
    int? titleLines;
    if (measurePass) {
      titleLines = null;
    } else if (keepFullTitleContent) {
      titleLines = 2;
    } else {
      titleLines = maxHeight >= 64 ? 2 : 1;
    }

    if (!keepFullTitleContent && hasBoundedHeight) {
      while (!_fits(showHeader, showFooter, titleLines, maxHeight)) {
        if (titleLines != null && titleLines > 1) {
          titleLines--;
          continue;
        }
        if (showHeader) {
          showHeader = false;
          continue;
        }
        break;
      }
    }

    final children = _buildChildren(
      showHeader: showHeader,
      showFooter: showFooter,
      titleLines: titleLines,
    );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );

    if (!hasBoundedHeight) return column;

    if (!_fits(showHeader, showFooter, titleLines, maxHeight)) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.bottomRight : Alignment.bottomLeft,
          child: column,
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRect(
        child: Align(
          alignment: alignEnd ? Alignment.bottomRight : Alignment.bottomLeft,
          child: column,
        ),
      ),
    );
  }

  List<Widget> _buildChildren({
    required bool showHeader,
    required bool showFooter,
    required int? titleLines,
  }) {
    final children = <Widget>[];
    if (showHeader) {
      children.add(titleHeader!);
      children.add(SizedBox(height: titleSpacing));
    }
    children.add(
      Text(
        title,
        style: titleStyle,
        maxLines: titleLines,
        overflow: keepFullTitleContent && titleLines == null
            ? TextOverflow.visible
            : TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      ),
    );
    if (showFooter) {
      children.add(SizedBox(height: titleSpacing));
      children.add(DefaultTextStyle(style: footerStyle, child: titleFooter!));
    }
    return children;
  }

  bool _fits(bool showHeader, bool showFooter, int? titleLines, double height) {
    const headerEstimate = 48.0;
    const footerEstimate = 48.0;
    const lineHeight = 30.0;

    var needed = 0.0;
    if (showHeader) {
      needed += headerEstimate + titleSpacing;
    }
    needed += (titleLines ?? 3) * lineHeight;
    if (showFooter) {
      needed += titleSpacing + footerEstimate;
    }
    return needed <= height;
  }
}

class _MeasureSize extends StatefulWidget {
  const _MeasureSize({
    required this.measureToken,
    required this.onChange,
    required this.child,
  });

  final Object measureToken;
  final ValueChanged<Size> onChange;
  final Widget child;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _oldSize;
  Object? _lastMeasureToken;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _MeasureSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measureToken != widget.measureToken) {
      _oldSize = null;
    }
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback(_reportSize);
  }

  void _reportSize(_) {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _scheduleMeasure();
      return;
    }

    final tokenChanged = _lastMeasureToken != widget.measureToken;
    if (!tokenChanged && _oldSize == box.size) return;

    _oldSize = box.size;
    _lastMeasureToken = widget.measureToken;
    widget.onChange(box.size);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Stretches [child] to fill the header with [BoxFit.cover].
class _FullBleedBackground extends StatelessWidget {
  const _FullBleedBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (child is Image) {
      final image = child as Image;
      return Image(
        key: image.key,
        image: image.image,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: image.alignment,
        color: image.color,
        colorBlendMode: image.colorBlendMode,
        filterQuality: image.filterQuality,
        gaplessPlayback: image.gaplessPlayback,
        semanticLabel: image.semanticLabel,
        excludeFromSemantics: image.excludeFromSemantics,
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }
}

/// Frosted toolbar icon background used in hero headers.
class CollapsingHeroIconButton extends StatelessWidget {
  const CollapsingHeroIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 56,
    this.radius = 16,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: const Color.fromRGBO(255, 255, 255, 0.1),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
