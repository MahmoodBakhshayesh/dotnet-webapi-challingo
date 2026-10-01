import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/extensions/context_extension.dart';
import 'app_picker_theme.dart';
import 'buttons/app_button.dart';
import 'buttons/app_outlined_button.dart';

/// Visual style of [AppCalendarPicker].
enum AppCalendarStyle {
  /// Classic paged month grid with animated month transitions (swipe on
  /// touch, chevrons on desktop) and full range-band rendering.
  monthGrid,

  /// Horizontal filmstrip of day cards (weekday / number / price) with snap
  /// feel — great for pricing timelines. Mouse wheel scrolls the strip.
  dateStrip,

  /// Continuous vertically-scrolling months (booking style) with a sticky
  /// weekday header — the most comfortable style for long ranges.
  verticalMonths,

  /// Drill-down chips: year → month → day with animated cascade
  /// transitions and a breadcrumb header.
  cascadeChips,

  /// iOS-style vertical wheels: day / month / year drums with a selection
  /// band. Single-date oriented; in range mode it edits the start date.
  wheels,

  /// Hero card: big animated day readout above a swipeable one-week strip —
  /// inspired by event/schedule card designs.
  heroCalendar,
}

/// Whether [AppCalendarPicker] picks one day or a start/end range.
enum AppCalendarMode { single, range }

/// Extra content rendered inside a day cell: a small [label] under the day
/// number (e.g. a price), an event [dot], and/or a [disabled] flag (e.g.
/// sold out).
class AppCalendarDayInfo {
  const AppCalendarDayInfo({
    this.label,
    this.labelColor,
    this.dot = false,
    this.dotColor,
    this.disabled = false,
  });

  final String? label;
  final Color? labelColor;
  final bool dot;
  final Color? dotColor;
  final bool disabled;
}

/// Resolves per-day decorations. Return null for a plain day.
typedef AppCalendarDayInfoBuilder = AppCalendarDayInfo? Function(DateTime day);

/// Current selection of an [AppCalendarPicker]. In single mode only [date]
/// is set; in range mode [start]/[end] fill in as the user taps.
class AppCalendarSelection {
  const AppCalendarSelection({this.date, this.start, this.end});

  final DateTime? date;
  final DateTime? start;
  final DateTime? end;

  bool get isComplete => date != null || (start != null && end != null);

  DateTimeRange? get range =>
      start != null && end != null ? DateTimeRange(start: start!, end: end!) : null;
}

bool _sameDay(DateTime? a, DateTime? b) =>
    a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _localeOf(BuildContext context) => Localizations.localeOf(context).toString();

/// Allow dragging scrollables with mouse/trackpad as well as touch, so the
/// strip and month lists feel right on web/desktop too.
class _AnyDeviceScrollBehavior extends MaterialScrollBehavior {
  const _AnyDeviceScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Embeddable date picker that renders as any [AppCalendarStyle], in single
/// or range [AppCalendarMode], with per-day decorations (pricing, events)
/// via [dayInfoBuilder].
///
/// All colors, radii, and action labels come from [theme]
/// (see [AppPickerTheme]); the default is the stock app look.
///
/// Interactions are tuned per platform: swipe/drag and tap on touch,
/// hover + mouse-wheel + chevrons on desktop/web.
///
/// For a ready-made modal flow use [showAppCalendarPicker].
class AppCalendarPicker extends StatefulWidget {
  const AppCalendarPicker({
    super.key,
    this.style = AppCalendarStyle.monthGrid,
    this.mode = AppCalendarMode.single,
    this.initialDate,
    this.initialRange,
    this.minDate,
    this.maxDate,
    this.dayInfoBuilder,
    this.onChanged,
    this.theme = const AppPickerTheme(),
  });

  final AppCalendarStyle style;
  final AppCalendarMode mode;
  final DateTime? initialDate;
  final DateTimeRange? initialRange;

  /// First selectable day (defaults to 1 year before today).
  final DateTime? minDate;

  /// Last selectable day (defaults to 2 years after today).
  final DateTime? maxDate;

  final AppCalendarDayInfoBuilder? dayInfoBuilder;
  final ValueChanged<AppCalendarSelection>? onChanged;

  /// Styling knobs; unset fields fall back to app defaults.
  final AppPickerTheme theme;

  @override
  State<AppCalendarPicker> createState() => _AppCalendarPickerState();
}

class _AppCalendarPickerState extends State<AppCalendarPicker> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _visibleMonth;

  AppPickerTheme get _t => widget.theme;

  DateTime get _min => _dateOnly(widget.minDate ?? DateTime.now().subtract(const Duration(days: 365)));
  DateTime get _max => _dateOnly(widget.maxDate ?? DateTime.now().add(const Duration(days: 730)));

  @override
  void initState() {
    super.initState();
    if (widget.mode == AppCalendarMode.range) {
      _start = widget.initialRange?.start;
      _end = widget.initialRange?.end;
    } else {
      _start = widget.initialDate;
    }
    final anchor = _start ?? DateTime.now();
    _visibleMonth = DateTime(anchor.year, anchor.month);
  }

  void _setVisibleMonth(DateTime month) => setState(() => _visibleMonth = month);

  AppCalendarSelection get _selection => widget.mode == AppCalendarMode.single
      ? AppCalendarSelection(date: _start)
      : AppCalendarSelection(start: _start, end: _end);

  void _onDayTap(DateTime day) {
    setState(() {
      if (widget.mode == AppCalendarMode.single) {
        _start = day;
      } else if (_start == null || _end != null) {
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _start = day;
      } else if (_sameDay(day, _start)) {
        _end = null;
      } else {
        _end = day;
      }
    });
    widget.onChanged?.call(_selection);
  }

  /// Continuous-control selection (wheels): always replaces the current
  /// single date / range start instead of toggling start → end.
  void _setSingle(DateTime day) {
    setState(() {
      _start = day;
      if (widget.mode == AppCalendarMode.range) _end = null;
    });
    widget.onChanged?.call(_selection);
  }

  bool _isDisabled(DateTime day, AppCalendarDayInfo? info) {
    if (info?.disabled ?? false) return true;
    final d = _dateOnly(day);
    return d.isBefore(_min) || d.isAfter(_max);
  }

  _DayCellState _cellState(DateTime day) {
    final info = widget.dayInfoBuilder?.call(day);
    final hasRange = _start != null && _end != null;
    final inRange = hasRange &&
        day.isAfter(_start!) &&
        day.isBefore(_end!) &&
        !_sameDay(day, _start) &&
        !_sameDay(day, _end);
    return _DayCellState(
      info: info,
      isToday: _sameDay(day, DateTime.now()),
      isStart: _sameDay(day, _start),
      isEnd: widget.mode == AppCalendarMode.range && _sameDay(day, _end),
      inRange: inRange,
      hasCompleteRange: hasRange,
      disabled: _isDisabled(day, info),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _AnyDeviceScrollBehavior(),
      child: switch (widget.style) {
        AppCalendarStyle.monthGrid => _MonthGridBody(host: this),
        AppCalendarStyle.dateStrip => _DateStripBody(host: this),
        AppCalendarStyle.verticalMonths => _VerticalMonthsBody(host: this),
        AppCalendarStyle.cascadeChips => _CascadeChipsBody(host: this),
        AppCalendarStyle.wheels => _WheelsBody(host: this),
        AppCalendarStyle.heroCalendar => _HeroCalendarBody(host: this),
      },
    );
  }
}

/// Modal wrapper around [AppCalendarPicker]: bottom sheet on phones, dialog
/// on wide layouts. Resolves with the confirmed [AppCalendarSelection] or
/// null when dismissed.
Future<AppCalendarSelection?> showAppCalendarPicker({
  required BuildContext context,
  AppCalendarStyle style = AppCalendarStyle.monthGrid,
  AppCalendarMode mode = AppCalendarMode.single,
  DateTime? initialDate,
  DateTimeRange? initialRange,
  DateTime? minDate,
  DateTime? maxDate,
  AppCalendarDayInfoBuilder? dayInfoBuilder,
  String? title,
  bool useRootNavigator = false,
  double breakpoint = 800,
  AppPickerTheme theme = const AppPickerTheme(),
}) {
  final content = _AppCalendarSheet(
    style: style,
    mode: mode,
    initialDate: initialDate,
    initialRange: initialRange,
    minDate: minDate,
    maxDate: maxDate,
    dayInfoBuilder: dayInfoBuilder,
    title: title,
    t: theme,
  );

  if (MediaQuery.sizeOf(context).width >= breakpoint) {
    return showDialog<AppCalendarSelection>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: theme.barrierColor,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: theme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.modalRadius * 0.7),
        ),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: content),
      ),
    );
  }
  return showModalBottomSheet<AppCalendarSelection>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    barrierColor: theme.barrierColor,
    backgroundColor: theme.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(theme.modalRadius)),
    ),
    builder: (context) => SafeArea(child: content),
  );
}

/// Range-only convenience over [showAppCalendarPicker], resolving with a
/// [DateTimeRange] (or null).
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  AppCalendarStyle style = AppCalendarStyle.verticalMonths,
  DateTimeRange? initialRange,
  DateTime? minDate,
  DateTime? maxDate,
  AppCalendarDayInfoBuilder? dayInfoBuilder,
  String? title,
  bool useRootNavigator = false,
  AppPickerTheme theme = const AppPickerTheme(),
}) async {
  final selection = await showAppCalendarPicker(
    context: context,
    style: style,
    mode: AppCalendarMode.range,
    initialRange: initialRange,
    minDate: minDate,
    maxDate: maxDate,
    dayInfoBuilder: dayInfoBuilder,
    title: title,
    useRootNavigator: useRootNavigator,
    theme: theme,
  );
  return selection?.range;
}

class _AppCalendarSheet extends StatefulWidget {
  const _AppCalendarSheet({
    required this.style,
    required this.mode,
    this.initialDate,
    this.initialRange,
    this.minDate,
    this.maxDate,
    this.dayInfoBuilder,
    this.title,
    this.t = const AppPickerTheme(),
  });

  final AppCalendarStyle style;
  final AppCalendarMode mode;
  final DateTime? initialDate;
  final DateTimeRange? initialRange;
  final DateTime? minDate;
  final DateTime? maxDate;
  final AppCalendarDayInfoBuilder? dayInfoBuilder;
  final String? title;
  final AppPickerTheme t;

  @override
  State<_AppCalendarSheet> createState() => _AppCalendarSheetState();
}

class _AppCalendarSheetState extends State<_AppCalendarSheet> {
  AppCalendarSelection _value = const AppCalendarSelection();

  @override
  void initState() {
    super.initState();
    _value = widget.mode == AppCalendarMode.single
        ? AppCalendarSelection(date: widget.initialDate)
        : AppCalendarSelection(
            start: widget.initialRange?.start, end: widget.initialRange?.end);
  }

  String get _summary {
    final locale = _localeOf(context);
    final fmt = DateFormat.MMMd(locale);
    if (widget.mode == AppCalendarMode.single) {
      return _value.date != null ? DateFormat.yMMMEd(locale).format(_value.date!) : '';
    }
    final start = _value.start != null ? fmt.format(_value.start!) : '…';
    final end = _value.end != null ? fmt.format(_value.end!) : '…';
    return _value.start == null && _value.end == null ? '' : '$start – $end';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.title != null) ...[
            Text(
              widget.title!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: t.headline,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Flexible(
            child: AppCalendarPicker(
              style: widget.style,
              mode: widget.mode,
              initialDate: widget.initialDate,
              initialRange: widget.initialRange,
              minDate: widget.minDate,
              maxDate: widget.maxDate,
              dayInfoBuilder: widget.dayInfoBuilder,
              theme: t,
              onChanged: (s) => setState(() => _value = s),
            ),
          ),
          const SizedBox(height: 12),
          if (_summary.isNotEmpty) ...[
            Text(
              _summary,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: t.headline,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: AppOutlinedButton(
                  label: t.cancelLabel ?? context.localizations.cancel,
                  textColor: t.cancelFg,
                  borderSide: BorderSide(color: t.cancelFg.withValues(alpha: 0.6)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: t.confirmLabel ?? context.localizations.confirm,
                  color: t.confirmFill,
                  textColor: t.confirmText,
                  disabled: !_value.isComplete,
                  onPressed: () => Navigator.of(context).pop(_value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- shared cell -------------------------------------------------------------

class _DayCellState {
  const _DayCellState({
    this.info,
    required this.isToday,
    required this.isStart,
    required this.isEnd,
    required this.inRange,
    required this.hasCompleteRange,
    required this.disabled,
  });

  final AppCalendarDayInfo? info;
  final bool isToday;
  final bool isStart;
  final bool isEnd;
  final bool inRange;
  final bool hasCompleteRange;
  final bool disabled;

  bool get isSelected => isStart || isEnd;
}

/// One day inside a month grid: animated selection circle, optional range
/// band behind it, label (price) and event dot below the number.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.state,
    required this.onTap,
    required this.t,
  });

  final DateTime day;
  final _DayCellState state;
  final VoidCallback onTap;
  final AppPickerTheme t;

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final info = state.info;
    final showBand = state.hasCompleteRange && (state.inRange || state.isSelected);

    final numberColor = state.disabled
        ? t.disabled
        : state.isSelected
            ? t.onPrimary
            : t.headline;

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (showBand)
            Positioned(
              top: 2,
              left: 0,
              right: 0,
              height: 36,
              child: Row(
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: state.isStart && !state.isEnd ? Colors.transparent : t.rangeBand,
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: state.isEnd && !state.isStart ? Colors.transparent : t.rangeBand,
                    ),
                  ),
                ],
              ),
            ),
          Column(
            children: [
              const SizedBox(height: 2),
              InkResponse(
                onTap: state.disabled ? null : onTap,
                radius: 24,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.isSelected ? t.primary : Colors.transparent,
                    border: state.isToday && !state.isSelected
                        ? Border.all(color: t.primary, width: 1.4)
                        : null,
                  ),
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: state.isSelected || state.isToday
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: numberColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (info?.label != null)
                Text(
                  info!.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: state.disabled ? t.disabled : info.labelColor ?? t.primary,
                  ),
                )
              else if (info?.dot ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: info!.dotColor ?? t.accent,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- month math --------------------------------------------------------------

/// Cells for a month grid: leading nulls to align the first day with the
/// locale's first weekday, then every day of the month.
List<DateTime?> _monthCells(DateTime month, int firstDayOfWeekIndex) {
  final first = DateTime(month.year, month.month, 1);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final leading = (first.weekday % 7 - firstDayOfWeekIndex + 7) % 7;
  return [
    for (var i = 0; i < leading; i++) null,
    for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d),
  ];
}

List<String> _weekdayNames(BuildContext context, int firstDayOfWeekIndex) {
  final locale = _localeOf(context);
  final fmt = DateFormat.E(locale);
  // 2023-01-01 is a Sunday (weekday index 0 in Material terms).
  final sunday = DateTime(2023, 1, 1);
  return [
    for (var i = 0; i < 7; i++)
      fmt.format(sunday.add(Duration(days: (firstDayOfWeekIndex + i) % 7))).characters.first,
  ];
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.firstDayOfWeekIndex, required this.t});

  final int firstDayOfWeekIndex;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    final names = _weekdayNames(context, firstDayOfWeekIndex);
    return Row(
      children: [
        for (final n in names)
          Expanded(
            child: Text(
              n,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: t.subhead,
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.host, required this.firstDayOfWeekIndex});

  final DateTime month;
  final _AppCalendarPickerState host;
  final int firstDayOfWeekIndex;

  @override
  Widget build(BuildContext context) {
    final cells = _monthCells(month, firstDayOfWeekIndex);
    final rows = (cells.length / 7).ceil();
    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: () {
                    final i = r * 7 + c;
                    final day = i < cells.length ? cells[i] : null;
                    if (day == null) return const SizedBox(height: _DayCell.height);
                    return _DayCell(
                      day: day,
                      state: host._cellState(day),
                      onTap: () => host._onDayTap(day),
                      t: host._t,
                    );
                  }(),
                ),
            ],
          ),
      ],
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.icon, required this.onPressed, required this.t});

  final IconData icon;
  final VoidCallback? onPressed;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: onPressed == null ? t.disabled : t.primary,
          ),
        ),
      ),
    );
  }
}

// --- style 1: paged month grid -----------------------------------------------

class _MonthGridBody extends StatefulWidget {
  const _MonthGridBody({required this.host});

  final _AppCalendarPickerState host;

  @override
  State<_MonthGridBody> createState() => _MonthGridBodyState();
}

class _MonthGridBodyState extends State<_MonthGridBody> {
  int _slideDir = 1;

  DateTime get _month => widget.host._visibleMonth;

  AppPickerTheme get t => widget.host._t;

  bool _canGo(int delta) {
    final target = DateTime(_month.year, _month.month + delta);
    final min = widget.host._min;
    final max = widget.host._max;
    final lastOfTarget = DateTime(target.year, target.month + 1, 0);
    return !lastOfTarget.isBefore(min) && !target.isAfter(max);
  }

  void _go(int delta) {
    if (!_canGo(delta)) return;
    setState(() => _slideDir = delta);
    widget.host._setVisibleMonth(DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final locale = _localeOf(context);
    final firstDow = MaterialLocalizations.of(context).firstDayOfWeekIndex;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _ChevronButton(
              icon: Icons.chevron_left,
              onPressed: _canGo(-1) ? () => _go(-1) : null,
              t: t,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0.2 * _slideDir, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  DateFormat.yMMMM(locale).format(_month),
                  key: ValueKey('${_month.year}-${_month.month}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.headline,
                  ),
                ),
              ),
            ),
            _ChevronButton(
              icon: Icons.chevron_right,
              onPressed: _canGo(1) ? () => _go(1) : null,
              t: t,
            ),
          ],
        ),
        const SizedBox(height: 6),
        _WeekdayHeader(firstDayOfWeekIndex: firstDow, t: t),
        const SizedBox(height: 4),
        // Swipe months on touch; the AnimatedSwitcher slides the grids.
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v < -150) _go(1);
            if (v > 150) _go(-1);
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0.12 * _slideDir, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              children: [...previousChildren, if (currentChild != null) currentChild],
            ),
            child: KeyedSubtree(
              key: ValueKey('${_month.year}-${_month.month}'),
              child: _MonthGrid(
                month: _month,
                host: widget.host,
                firstDayOfWeekIndex: firstDow,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- style 2: horizontal date strip -------------------------------------------

class _DateStripBody extends StatefulWidget {
  const _DateStripBody({required this.host});

  final _AppCalendarPickerState host;

  @override
  State<_DateStripBody> createState() => _DateStripBodyState();
}

class _DateStripBodyState extends State<_DateStripBody> {
  static const double _itemExtent = 68;

  late final ScrollController _controller;
  late DateTime _headerDate;

  _AppCalendarPickerState get host => widget.host;

  AppPickerTheme get t => host._t;

  int get _dayCount => _dateOnly(host._max).difference(_dateOnly(host._min)).inDays + 1;

  DateTime _dayAt(int index) => _dateOnly(host._min).add(Duration(days: index));

  int _indexOf(DateTime day) => _dateOnly(day).difference(_dateOnly(host._min)).inDays;

  @override
  void initState() {
    super.initState();
    final anchor = host._start ?? DateTime.now();
    final initialIndex = _indexOf(anchor).clamp(0, _dayCount - 1);
    _headerDate = _dayAt(initialIndex);
    _controller = ScrollController(initialScrollOffset: initialIndex * _itemExtent);
    _controller.addListener(_syncHeader);
  }

  void _syncHeader() {
    final index = (_controller.offset / _itemExtent).round().clamp(0, _dayCount - 1);
    final date = _dayAt(index);
    if (date.month != _headerDate.month || date.year != _headerDate.year) {
      setState(() => _headerDate = date);
    }
  }

  void _page(int direction) {
    final width = _controller.position.viewportDimension;
    _controller.animateTo(
      (_controller.offset + direction * width * 0.8)
          .clamp(0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = _localeOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  DateFormat.yMMMM(locale).format(_headerDate),
                  key: ValueKey('${_headerDate.year}-${_headerDate.month}'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.headline,
                  ),
                ),
              ),
            ),
            _ChevronButton(icon: Icons.chevron_left, onPressed: () => _page(-1), t: t),
            _ChevronButton(icon: Icons.chevron_right, onPressed: () => _page(1), t: t),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          // Map mouse wheel (vertical) onto the horizontal strip.
          child: Listener(
            onPointerSignal: (signal) {
              if (signal is PointerScrollEvent && _controller.hasClients) {
                final delta = signal.scrollDelta.dy.abs() > signal.scrollDelta.dx.abs()
                    ? signal.scrollDelta.dy
                    : signal.scrollDelta.dx;
                _controller.jumpTo(
                  (_controller.offset + delta)
                      .clamp(0, _controller.position.maxScrollExtent),
                );
              }
            },
            child: ListView.builder(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              itemExtent: _itemExtent,
              itemCount: _dayCount,
              itemBuilder: (context, index) {
                final day = _dayAt(index);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _StripCard(
                    day: day,
                    state: host._cellState(day),
                    onTap: () => host._onDayTap(day),
                    t: t,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _StripReadout(host: host),
      ],
    );
  }
}

class _StripCard extends StatelessWidget {
  const _StripCard({
    required this.day,
    required this.state,
    required this.onTap,
    required this.t,
  });

  final DateTime day;
  final _DayCellState state;
  final VoidCallback onTap;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    final locale = _localeOf(context);
    final selected = state.isSelected;
    final tinted = state.inRange;
    final info = state.info;
    final radius = BorderRadius.circular(t.radius + 4);

    final fg = state.disabled
        ? t.disabled
        : selected
            ? t.onPrimary
            : t.headline;

    return InkWell(
      onTap: state.disabled ? null : onTap,
      borderRadius: radius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        margin: EdgeInsets.symmetric(vertical: selected ? 0 : 6),
        decoration: BoxDecoration(
          borderRadius: radius,
          color: selected
              ? t.primary
              : tinted
                  ? t.rangeBand
                  : t.background,
          border: Border.all(
            color: selected
                ? t.primary
                : state.isToday
                    ? t.primary.withValues(alpha: 0.6)
                    : t.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: t.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat.E(locale).format(day),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? t.onPrimary.withValues(alpha: 0.7) : t.subhead,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: selected ? 24 : 20,
                fontWeight: FontWeight.w800,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            if (info?.label != null)
              Text(
                info!.label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? t.onPrimary : info.labelColor ?? t.primary,
                ),
              )
            else if (info?.dot ?? false)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: info!.dotColor ?? t.accent,
                ),
              )
            else
              const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _StripReadout extends StatelessWidget {
  const _StripReadout({required this.host});

  final _AppCalendarPickerState host;

  @override
  Widget build(BuildContext context) {
    final t = host._t;
    final locale = _localeOf(context);
    final selection = host._selection;
    final date = selection.date ?? selection.start;
    if (date == null) return const SizedBox(height: 30);

    final fmt = DateFormat.MMMEd(locale);
    final text = host.widget.mode == AppCalendarMode.single || selection.end == null
        ? fmt.format(date)
        : '${fmt.format(selection.start!)} – ${fmt.format(selection.end!)}';
    final info = selection.end == null ? host.widget.dayInfoBuilder?.call(date) : null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Column(
        key: ValueKey(text),
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: t.headline,
            ),
          ),
          if (info?.label != null)
            Text(
              info!.label!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: info.labelColor ?? t.primary,
              ),
            ),
        ],
      ),
    );
  }
}

// --- style 3: vertical continuous months --------------------------------------

class _VerticalMonthsBody extends StatefulWidget {
  const _VerticalMonthsBody({required this.host});

  final _AppCalendarPickerState host;

  @override
  State<_VerticalMonthsBody> createState() => _VerticalMonthsBodyState();
}

class _VerticalMonthsBodyState extends State<_VerticalMonthsBody> {
  final ScrollController _controller = ScrollController();

  _AppCalendarPickerState get host => widget.host;

  int get _monthCount {
    final min = host._min;
    final max = host._max;
    return (max.year - min.year) * 12 + max.month - min.month + 1;
  }

  DateTime _monthAt(int index) => DateTime(host._min.year, host._min.month + index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = host._t;
    final locale = _localeOf(context);
    final firstDow = MaterialLocalizations.of(context).firstDayOfWeekIndex;

    return SizedBox(
      height: 420,
      child: Column(
        children: [
          _WeekdayHeader(firstDayOfWeekIndex: firstDow, t: t),
          const SizedBox(height: 4),
          const Divider(height: 1),
          Expanded(
            child: Scrollbar(
              controller: _controller,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _controller,
                itemCount: _monthCount,
                itemBuilder: (context, index) {
                  final month = _monthAt(index);
                  return Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 4),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.yMMMM(locale).format(month),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: t.headline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _MonthGrid(
                          month: month,
                          host: host,
                          firstDayOfWeekIndex: firstDow,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- style 4: cascade chips ----------------------------------------------------

enum _CascadeLevel { year, month, day }

class _CascadeChipsBody extends StatefulWidget {
  const _CascadeChipsBody({required this.host});

  final _AppCalendarPickerState host;

  @override
  State<_CascadeChipsBody> createState() => _CascadeChipsBodyState();
}

class _CascadeChipsBodyState extends State<_CascadeChipsBody> {
  _CascadeLevel _level = _CascadeLevel.day;
  int _slideDir = 1;

  _AppCalendarPickerState get host => widget.host;

  AppPickerTheme get t => host._t;

  DateTime get _month => host._visibleMonth;

  void _goTo(_CascadeLevel level, {int dir = 1}) {
    setState(() {
      _slideDir = dir;
      _level = level;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = _localeOf(context);

    Widget crumb(String text, {required bool active, required VoidCallback onTap}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: active ? t.primary : t.background,
            border: Border.all(color: active ? t.primary : t.border),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? t.onPrimary : t.primary,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            crumb(
              DateFormat.y(locale).format(_month),
              active: _level == _CascadeLevel.year,
              onTap: () => _goTo(_CascadeLevel.year, dir: -1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 18, color: t.subhead),
            ),
            crumb(
              DateFormat.MMMM(locale).format(_month),
              active: _level == _CascadeLevel.month,
              onTap: () => _goTo(_CascadeLevel.month, dir: -1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.15 * _slideDir, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topCenter,
            children: [...previousChildren, if (currentChild != null) currentChild],
          ),
          child: KeyedSubtree(
            key: ValueKey('$_level-${_month.year}-${_month.month}'),
            child: switch (_level) {
              _CascadeLevel.year => _buildYears(),
              _CascadeLevel.month => _buildMonths(locale),
              _CascadeLevel.day => _buildDays(),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYears() {
    final years = [for (var y = host._min.year; y <= host._max.year; y++) y];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final y in years)
          _CascadeChip(
            text: '$y',
            selected: y == _month.year,
            t: t,
            onTap: () {
              host._setVisibleMonth(DateTime(y, _month.month));
              _goTo(_CascadeLevel.month);
            },
          ),
      ],
    );
  }

  Widget _buildMonths(String locale) {
    final fmt = DateFormat.MMM(locale);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (var m = 1; m <= 12; m++)
          () {
            final month = DateTime(_month.year, m);
            final lastOfMonth = DateTime(month.year, m + 1, 0);
            final enabled = !lastOfMonth.isBefore(host._min) && !month.isAfter(host._max);
            return _CascadeChip(
              text: fmt.format(month),
              selected: m == _month.month,
              disabled: !enabled,
              t: t,
              onTap: () {
                host._setVisibleMonth(month);
                _goTo(_CascadeLevel.day);
              },
            );
          }(),
      ],
    );
  }

  Widget _buildDays() {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (var d = 1; d <= daysInMonth; d++)
          () {
            final day = DateTime(_month.year, _month.month, d);
            final state = host._cellState(day);
            final info = state.info;
            return _CascadeChip(
              text: '$d',
              subText: info?.label,
              dotColor: (info?.dot ?? false) ? (info!.dotColor ?? t.accent) : null,
              selected: state.isSelected,
              tinted: state.inRange,
              outlined: state.isToday,
              disabled: state.disabled,
              t: t,
              onTap: () => host._onDayTap(day),
            );
          }(),
      ],
    );
  }
}

class _CascadeChip extends StatelessWidget {
  const _CascadeChip({
    required this.text,
    required this.selected,
    required this.onTap,
    required this.t,
    this.subText,
    this.dotColor,
    this.tinted = false,
    this.outlined = false,
    this.disabled = false,
  });

  final String text;
  final String? subText;
  final Color? dotColor;
  final bool selected;
  final bool tinted;
  final bool outlined;
  final bool disabled;
  final VoidCallback onTap;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    final fg = disabled
        ? t.disabled
        : selected
            ? t.onPrimary
            : t.headline;

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(t.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radius),
          color: selected
              ? t.primary
              : tinted
                  ? t.rangeBand
                  : t.background,
          border: Border.all(
            color: selected || outlined ? t.primary : t.border,
            width: outlined && !selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: t.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (subText != null)
              Text(
                subText!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: selected ? t.onPrimary : t.primary,
                ),
              )
            else if (dotColor != null)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
              ),
          ],
        ),
      ),
    );
  }
}

// --- style 5: iOS-style wheels -------------------------------------------------

class _WheelsBody extends StatefulWidget {
  const _WheelsBody({required this.host});

  final _AppCalendarPickerState host;

  @override
  State<_WheelsBody> createState() => _WheelsBodyState();
}

class _WheelsBodyState extends State<_WheelsBody> {
  late DateTime _value;
  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _yearCtrl;

  _AppCalendarPickerState get host => widget.host;

  AppPickerTheme get t => host._t;

  int get _minYear => host._min.year;
  int get _yearCount => host._max.year - _minYear + 1;

  int _daysIn(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

  @override
  void initState() {
    super.initState();
    _value = _dateOnly(host._start ?? DateTime.now());
    if (_value.isBefore(host._min)) _value = host._min;
    if (_value.isAfter(host._max)) _value = host._max;
    _dayCtrl = FixedExtentScrollController(initialItem: _value.day - 1);
    _monthCtrl = FixedExtentScrollController(initialItem: _value.month - 1);
    _yearCtrl = FixedExtentScrollController(initialItem: _value.year - _minYear);
    // Report the initial wheel value so the sheet can enable confirm.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) host._setSingle(_value);
    });
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _update({int? day, int? month, int? year}) {
    var next = DateTime(
      year ?? _value.year,
      month ?? _value.month,
      1,
    );
    final maxDay = _daysIn(next);
    var nextDay = (day ?? _value.day).clamp(1, maxDay);
    next = DateTime(next.year, next.month, nextDay);
    if (next.isBefore(host._min)) next = host._min;
    if (next.isAfter(host._max)) next = host._max;
    setState(() => _value = next);
    host._setSingle(next);
    // Keep the day wheel in bounds when the month shrank.
    if (_dayCtrl.hasClients && _dayCtrl.selectedItem != next.day - 1 && day == null) {
      _dayCtrl.animateToItem(
        next.day - 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = _localeOf(context);
    final monthFmt = DateFormat.MMMM(locale);

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Selection band behind the wheels.
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: t.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(t.radius),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DateWheel(
                controller: _dayCtrl,
                width: 64,
                itemCount: _daysIn(_value),
                looping: true,
                t: t,
                labelOf: (i) => '${i + 1}',
                selectedIndex: _value.day - 1,
                onChanged: (i) => _update(day: i + 1),
              ),
              _DateWheel(
                controller: _monthCtrl,
                width: 140,
                itemCount: 12,
                looping: true,
                t: t,
                labelOf: (i) => monthFmt.format(DateTime(2000, i + 1)),
                selectedIndex: _value.month - 1,
                onChanged: (i) => _update(month: i + 1),
              ),
              _DateWheel(
                controller: _yearCtrl,
                width: 80,
                itemCount: _yearCount,
                looping: false,
                t: t,
                labelOf: (i) => '${_minYear + i}',
                selectedIndex: _value.year - _minYear,
                onChanged: (i) => _update(year: _minYear + i),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateWheel extends StatelessWidget {
  const _DateWheel({
    required this.controller,
    required this.width,
    required this.itemCount,
    required this.looping,
    required this.labelOf,
    required this.selectedIndex,
    required this.onChanged,
    required this.t,
  });

  final FixedExtentScrollController controller;
  final double width;
  final int itemCount;
  final bool looping;
  final String Function(int index) labelOf;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (var i = 0; i < itemCount; i++)
        Center(
          child: Text(
            labelOf(i),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w400,
              color: i == selectedIndex ? t.headline : t.subhead,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
    ];

    return SizedBox(
      width: width,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 40,
        perspective: 0.004,
        diameterRatio: 1.6,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) => onChanged(looping ? i % itemCount : i),
        childDelegate: looping
            ? ListWheelChildLoopingListDelegate(children: children)
            : ListWheelChildListDelegate(children: children),
      ),
    );
  }
}

// --- style 6: hero calendar -----------------------------------------------------

class _HeroCalendarBody extends StatefulWidget {
  const _HeroCalendarBody({required this.host});

  final _AppCalendarPickerState host;

  @override
  State<_HeroCalendarBody> createState() => _HeroCalendarBodyState();
}

class _HeroCalendarBodyState extends State<_HeroCalendarBody> {
  DateTime? _weekStart;
  int _slideDir = 1;

  _AppCalendarPickerState get host => widget.host;

  AppPickerTheme get t => host._t;

  DateTime _startOfWeek(DateTime day) {
    // MaterialLocalizations: 0 = Sunday; DateTime.weekday: 7 = Sunday.
    final firstDow = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final delta = (day.weekday % 7 - firstDow + 7) % 7;
    return _dateOnly(day).subtract(Duration(days: delta));
  }

  void _shiftWeek(int direction) {
    setState(() {
      _slideDir = direction;
      _weekStart = _weekStart!.add(Duration(days: 7 * direction));
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = _localeOf(context);
    final hero = host._start ?? DateTime.now();
    final weekStart = _weekStart ??= _startOfWeek(hero);
    final heroInfo = host.widget.dayInfoBuilder?.call(hero);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hero readout with animated day swap.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey(_dateOnly(hero)),
            children: [
              Text(
                DateFormat.EEEE(locale).format(hero),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: t.subhead,
                ),
              ),
              Text(
                '${hero.day}',
                style: TextStyle(
                  fontSize: 64,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: t.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                DateFormat.yMMMM(locale).format(hero),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: t.headline,
                ),
              ),
              if (heroInfo?.label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    heroInfo!.label!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: heroInfo.labelColor ?? t.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Week strip with chevrons; swipe or click through weeks.
        Row(
          children: [
            _ChevronButton(icon: Icons.chevron_left, onPressed: () => _shiftWeek(-1), t: t),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v < -150) _shiftWeek(1);
                  if (v > 150) _shiftWeek(-1);
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0.25 * _slideDir, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Row(
                    key: ValueKey(weekStart),
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: _HeroWeekDay(
                            day: weekStart.add(Duration(days: i)),
                            host: host,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            _ChevronButton(icon: Icons.chevron_right, onPressed: () => _shiftWeek(1), t: t),
          ],
        ),
      ],
    );
  }
}

class _HeroWeekDay extends StatelessWidget {
  const _HeroWeekDay({required this.day, required this.host});

  final DateTime day;
  final _AppCalendarPickerState host;

  @override
  Widget build(BuildContext context) {
    final t = host._t;
    final locale = _localeOf(context);
    final state = host._cellState(day);
    final selected = state.isSelected;

    return InkWell(
      onTap: state.disabled ? null : () => host._onDayTap(day),
      borderRadius: BorderRadius.circular(t.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radius),
          color: selected
              ? t.primary
              : state.inRange
                  ? t.rangeBand
                  : Colors.transparent,
          border: state.isToday && !selected
              ? Border.all(color: t.primary.withValues(alpha: 0.7))
              : null,
        ),
        child: Column(
          children: [
            Text(
              DateFormat.E(locale).format(day).characters.first,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? t.onPrimary.withValues(alpha: 0.75) : t.subhead,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: state.disabled
                    ? t.disabled
                    : selected
                        ? t.onPrimary
                        : t.headline,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 3),
            if (state.info?.dot ?? false)
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.info!.dotColor ?? t.accent,
                ),
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
