import 'package:flutter/material.dart';

import '../core/extensions/context_extension.dart';
import '../core/theme/app_colors.dart';
import 'app_calendar_picker.dart';
import 'app_picker_theme.dart';
import 'app_time_picker.dart';
import 'buttons/app_button.dart';
import 'buttons/app_outlined_button.dart';

/// What an [showAppDateTimePicker] session lets the user edit.
enum AppDateTimePickerMode { date, time, dateAndTime }

/// First-party replacement for the previously vendored board date/time
/// picker. Opens a bottom sheet on narrow layouts and a dialog on wide ones,
/// and resolves with the picked [DateTime] (or null when dismissed).
///
/// - [AppDateTimePickerMode.date] → calendar grid.
/// - [AppDateTimePickerMode.time] → hour/minute wheels.
/// - [AppDateTimePickerMode.dateAndTime] → calendar with time wheels below.
Future<DateTime?> showAppDateTimePicker({
  required BuildContext context,
  AppDateTimePickerMode mode = AppDateTimePickerMode.dateAndTime,
  DateTime? initialDate,
  DateTime? minimumDate,
  DateTime? maximumDate,
  String? title,
  bool useRootNavigator = false,
  double breakpoint = 800,
  Color? barrierColor,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final content = _AppDateTimePickerContent(
    mode: mode,
    initialDate: initialDate ?? DateTime.now(),
    minimumDate: minimumDate,
    maximumDate: maximumDate,
    title: title,
  );

  if (width >= breakpoint) {
    return showDialog<DateTime>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: barrierColor,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: content,
        ),
      ),
    );
  }
  return showModalBottomSheet<DateTime>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierColor: barrierColor,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(child: content),
  );
}

/// Convenience wrapper: calendar-only picker resolving to a day (midnight),
/// rendered as any [AppCalendarStyle]. [dayInfoBuilder] decorates day cells
/// with price labels / event dots.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? minimumDate,
  DateTime? maximumDate,
  String? title,
  bool useRootNavigator = false,
  AppCalendarStyle style = AppCalendarStyle.monthGrid,
  AppCalendarDayInfoBuilder? dayInfoBuilder,
  AppPickerTheme theme = const AppPickerTheme(),
}) async {
  final selection = await showAppCalendarPicker(
    context: context,
    style: style,
    mode: AppCalendarMode.single,
    initialDate: initialDate,
    minDate: minimumDate,
    maxDate: maximumDate,
    dayInfoBuilder: dayInfoBuilder,
    title: title,
    useRootNavigator: useRootNavigator,
    theme: theme,
  );
  return selection?.date;
}

/// Convenience wrapper: time-only picker rendered as any
/// [AppTimePickerStyle]. The returned [DateTime] keeps [initialDate]'s
/// calendar day with the picked hour/minute.
Future<DateTime?> showAppTimePicker({
  required BuildContext context,
  DateTime? initialDate,
  String? title,
  bool useRootNavigator = false,
  AppTimePickerStyle style = AppTimePickerStyle.rulerTape,
  List<TimeOfDay> presets = const [],
  bool includeNowPreset = false,
  AppPickerTheme theme = const AppPickerTheme(),
}) async {
  final base = initialDate ?? DateTime.now();
  final picked = await showAppTimePickerSheet(
    context: context,
    style: style,
    initialTime: TimeOfDay.fromDateTime(base),
    title: title,
    presets: presets,
    includeNowPreset: includeNowPreset,
    useRootNavigator: useRootNavigator,
    theme: theme,
  );
  if (picked == null) return null;
  return DateTime(base.year, base.month, base.day, picked.hour, picked.minute);
}

class _AppDateTimePickerContent extends StatefulWidget {
  const _AppDateTimePickerContent({
    required this.mode,
    required this.initialDate,
    this.minimumDate,
    this.maximumDate,
    this.title,
  });

  final AppDateTimePickerMode mode;
  final DateTime initialDate;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final String? title;

  @override
  State<_AppDateTimePickerContent> createState() => _AppDateTimePickerContentState();
}

class _AppDateTimePickerContentState extends State<_AppDateTimePickerContent> {
  late DateTime _value;

  bool get _showDate => widget.mode != AppDateTimePickerMode.time;
  bool get _showTime => widget.mode != AppDateTimePickerMode.date;

  @override
  void initState() {
    super.initState();
    var initial = widget.initialDate;
    final min = widget.minimumDate;
    final max = widget.maximumDate;
    if (min != null && initial.isBefore(min)) initial = min;
    if (max != null && initial.isAfter(max)) initial = max;
    _value = initial;
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _value = DateTime(date.year, date.month, date.day, _value.hour, _value.minute);
    });
  }

  void _onTimeChanged({int? hour, int? minute}) {
    setState(() {
      _value = DateTime(
        _value.year,
        _value.month,
        _value.day,
        hour ?? _value.hour,
        minute ?? _value.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.headlineColor,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (_showDate)
            CalendarDatePicker(
              initialDate: _value,
              firstDate: widget.minimumDate ?? DateTime(1900),
              lastDate: widget.maximumDate ?? DateTime(2100),
              onDateChanged: _onDateChanged,
            ),
          if (_showTime)
            _TimeWheels(
              hour: _value.hour,
              minute: _value.minute,
              onChanged: _onTimeChanged,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppOutlinedButton(
                  label: context.localizations.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: context.localizations.confirm,
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

/// Hour/minute wheel pair with a selection highlight band.
class _TimeWheels extends StatelessWidget {
  const _TimeWheels({required this.hour, required this.minute, required this.onChanged});

  final int hour;
  final int minute;
  final void Function({int? hour, int? minute}) onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Selection band behind the wheels.
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NumberWheel(
                value: hour,
                itemCount: 24,
                onChanged: (v) => onChanged(hour: v),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headlineColor,
                  ),
                ),
              ),
              _NumberWheel(
                value: minute,
                itemCount: 60,
                onChanged: (v) => onChanged(minute: v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberWheel extends StatefulWidget {
  const _NumberWheel({required this.value, required this.itemCount, required this.onChanged});

  final int value;
  final int itemCount;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberWheel> createState() => _NumberWheelState();
}

class _NumberWheelState extends State<_NumberWheel> {
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: widget.value);
  }

  @override
  void didUpdateWidget(covariant _NumberWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.selectedItem) {
      _controller.jumpToItem(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: 40,
        perspective: 0.004,
        diameterRatio: 1.6,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: widget.onChanged,
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var i = 0; i < widget.itemCount; i++)
              Center(
                child: Text(
                  i.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: i == widget.value ? FontWeight.w700 : FontWeight.w400,
                    color: i == widget.value ? AppColors.headlineColor : AppColors.subheadColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
