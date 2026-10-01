import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/extensions/context_extension.dart';
import 'app_picker_theme.dart';
import 'buttons/app_button.dart';
import 'buttons/app_outlined_button.dart';

/// Visual style of [AppTimePicker].
enum AppTimePickerStyle {
  /// Two horizontal measuring-tape strips (hours / minutes) with a fixed
  /// center indicator and a large live readout.
  rulerTape,

  /// Semicircular arc slider for the hour, slim slider for minutes, and
  /// +/- steppers for one-minute adjustments.
  arcSlider,

  /// Tappable 0–23 hour chip grid with a minute slider — fastest input,
  /// no scrolling.
  digitPad,

  /// Vertical day rail (00–24 with day/night tint) with a draggable handle,
  /// minute chips, and one-minute fine-adjust arrows.
  timelineRail,

  /// Analog clock face: drag or tap the dial to set the hour (24h dual
  /// ring), auto-advancing to the minute ring; tap the readout to switch.
  clockDial,
}

/// Embeddable 24h time picker that renders as any of the
/// [AppTimePickerStyle] concepts. Keeps hour/minute state internally and
/// reports every change through [onChanged].
///
/// All colors, radii, and action labels come from [theme]
/// (see [AppPickerTheme]); the default is the stock app look.
///
/// For a ready-made modal flow use [showAppTimePickerSheet] (bottom sheet on
/// phones, dialog on wide layouts).
class AppTimePicker extends StatefulWidget {
  const AppTimePicker({
    super.key,
    this.style = AppTimePickerStyle.rulerTape,
    required this.initialTime,
    required this.onChanged,
    this.presets = const [],
    this.includeNowPreset = false,
    this.theme = const AppPickerTheme(),
  });

  final AppTimePickerStyle style;
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onChanged;

  /// Quick-pick chips shown under the picker (e.g. `09:00`, `18:00`).
  final List<TimeOfDay> presets;

  /// Prepends a localized "Now" chip to [presets].
  final bool includeNowPreset;

  /// Styling knobs; unset fields fall back to app defaults.
  final AppPickerTheme theme;

  @override
  State<AppTimePicker> createState() => _AppTimePickerState();
}

class _AppTimePickerState extends State<AppTimePicker> {
  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;

  AppPickerTheme get _t => widget.theme;

  void _set({int? hour, int? minute}) {
    setState(() {
      _hour = (hour ?? _hour).clamp(0, 23);
      _minute = (minute ?? _minute).clamp(0, 59);
    });
    widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (widget.style) {
      AppTimePickerStyle.rulerTape =>
        _RulerTapeBody(hour: _hour, minute: _minute, onSet: _set, t: _t),
      AppTimePickerStyle.arcSlider =>
        _ArcSliderBody(hour: _hour, minute: _minute, onSet: _set, t: _t),
      AppTimePickerStyle.digitPad =>
        _DigitPadBody(hour: _hour, minute: _minute, onSet: _set, t: _t),
      AppTimePickerStyle.timelineRail =>
        _TimelineRailBody(hour: _hour, minute: _minute, onSet: _set, t: _t),
      AppTimePickerStyle.clockDial =>
        _ClockDialBody(hour: _hour, minute: _minute, onSet: _set, t: _t),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        if (widget.includeNowPreset || widget.presets.isNotEmpty) ...[
          const SizedBox(height: 14),
          _PresetChips(
            presets: widget.presets,
            includeNow: widget.includeNowPreset,
            onPick: (t) => _set(hour: t.hour, minute: t.minute),
            t: _t,
          ),
        ],
      ],
    );
  }
}

/// Modal wrapper around [AppTimePicker]: bottom sheet below [breakpoint],
/// dialog above it. Resolves with the confirmed [TimeOfDay] or null.
Future<TimeOfDay?> showAppTimePickerSheet({
  required BuildContext context,
  AppTimePickerStyle style = AppTimePickerStyle.rulerTape,
  TimeOfDay? initialTime,
  String? title,
  List<TimeOfDay> presets = const [],
  bool includeNowPreset = false,
  bool useRootNavigator = false,
  double breakpoint = 800,
  AppPickerTheme theme = const AppPickerTheme(),
}) {
  final content = _AppTimePickerSheet(
    style: style,
    initialTime: initialTime ?? TimeOfDay.now(),
    title: title,
    presets: presets,
    includeNowPreset: includeNowPreset,
    t: theme,
  );

  if (MediaQuery.sizeOf(context).width >= breakpoint) {
    return showDialog<TimeOfDay>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: theme.barrierColor,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: theme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.modalRadius * 0.7),
        ),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: content),
      ),
    );
  }
  return showModalBottomSheet<TimeOfDay>(
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

class _AppTimePickerSheet extends StatefulWidget {
  const _AppTimePickerSheet({
    required this.style,
    required this.initialTime,
    this.title,
    this.presets = const [],
    this.includeNowPreset = false,
    this.t = const AppPickerTheme(),
  });

  final AppTimePickerStyle style;
  final TimeOfDay initialTime;
  final String? title;
  final List<TimeOfDay> presets;
  final bool includeNowPreset;
  final AppPickerTheme t;

  @override
  State<_AppTimePickerSheet> createState() => _AppTimePickerSheetState();
}

class _AppTimePickerSheetState extends State<_AppTimePickerSheet> {
  late TimeOfDay _value = widget.initialTime;

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
          AppTimePicker(
            style: widget.style,
            initialTime: widget.initialTime,
            presets: widget.presets,
            includeNowPreset: widget.includeNowPreset,
            theme: t,
            onChanged: (v) => _value = v,
          ),
          const SizedBox(height: 16),
          _PickerActions(
            t: t,
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () => Navigator.of(context).pop(_value),
          ),
        ],
      ),
    );
  }
}

/// Cancel/confirm row shared by the picker sheets, honoring the theme's
/// action labels and colors.
class _PickerActions extends StatelessWidget {
  const _PickerActions({
    required this.t,
    required this.onCancel,
    required this.onConfirm,
  });

  final AppPickerTheme t;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppOutlinedButton(
            label: t.cancelLabel ?? context.localizations.cancel,
            textColor: t.cancelFg,
            borderSide: BorderSide(color: t.cancelFg.withValues(alpha: 0.6)),
            onPressed: onCancel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: AppButton(
            label: t.confirmLabel ?? context.localizations.confirm,
            color: t.confirmFill,
            textColor: t.confirmText,
            onPressed: onConfirm,
          ),
        ),
      ],
    );
  }
}

// --- shared pieces -----------------------------------------------------------

typedef _SetTime = void Function({int? hour, int? minute});

String _two(int v) => v.toString().padLeft(2, '0');

class _TimeReadout extends StatelessWidget {
  const _TimeReadout({
    required this.hour,
    required this.minute,
    required this.t,
    this.fontSize = 44,
    this.hourColor,
    this.minuteColor,
  });

  final int hour;
  final int minute;
  final AppPickerTheme t;
  final double fontSize;
  final Color? hourColor;
  final Color? minuteColor;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: _two(hour), style: base.copyWith(color: hourColor ?? t.headline)),
        TextSpan(text: ':', style: base.copyWith(color: t.subhead)),
        TextSpan(text: _two(minute), style: base.copyWith(color: minuteColor ?? t.headline)),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

class _PresetChips extends StatelessWidget {
  const _PresetChips({
    required this.presets,
    required this.includeNow,
    required this.onPick,
    required this.t,
  });

  final List<TimeOfDay> presets;
  final bool includeNow;
  final ValueChanged<TimeOfDay> onPick;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    Widget chip({required Widget label, required VoidCallback onTap}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.primary.withValues(alpha: 0.6)),
          ),
          child: label,
        ),
      );
    }

    final labelStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: t.primary,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (includeNow)
          chip(
            onTap: () => onPick(TimeOfDay.now()),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Icon(Icons.schedule, size: 14, color: t.primary),
                Text(context.localizations.now, style: labelStyle),
              ],
            ),
          ),
        for (final v in presets)
          chip(
            onTap: () => onPick(v),
            label: Text('${_two(v.hour)}:${_two(v.minute)}', style: labelStyle),
          ),
      ],
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({required this.icon, required this.onPressed, required this.t});

  final IconData icon;
  final VoidCallback onPressed;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: t.background,
      shape: CircleBorder(side: BorderSide(color: t.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: t.primary),
        ),
      ),
    );
  }
}

class _MinuteSlider extends StatelessWidget {
  const _MinuteSlider({required this.minute, required this.onChanged, required this.t});

  final int minute;
  final ValueChanged<int> onChanged;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: t.primary,
        inactiveTrackColor: t.border,
        thumbColor: t.primary,
        overlayColor: t.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      child: Slider(
        value: minute.toDouble(),
        min: 0,
        max: 59,
        divisions: 59,
        label: _two(minute),
        onChanged: (v) => onChanged(v.round()),
      ),
    );
  }
}

// --- style 1: ruler tape -----------------------------------------------------

class _RulerTapeBody extends StatelessWidget {
  const _RulerTapeBody({
    required this.hour,
    required this.minute,
    required this.onSet,
    required this.t,
  });

  final int hour;
  final int minute;
  final _SetTime onSet;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TimeReadout(hour: hour, minute: minute, t: t),
        const SizedBox(height: 12),
        _RulerTape(count: 24, value: hour, onChanged: (v) => onSet(hour: v), t: t),
        const SizedBox(height: 16),
        _RulerTape(count: 60, value: minute, onChanged: (v) => onSet(minute: v), t: t),
      ],
    );
  }
}

/// One horizontal tape: a rotated [ListWheelScrollView] (flattened, looping,
/// snapping) with tick marks per item and a fixed center indicator.
class _RulerTape extends StatefulWidget {
  const _RulerTape({
    required this.count,
    required this.value,
    required this.onChanged,
    required this.t,
  });

  final int count;
  final int value;
  final ValueChanged<int> onChanged;
  final AppPickerTheme t;

  @override
  State<_RulerTape> createState() => _RulerTapeState();
}

class _RulerTapeState extends State<_RulerTape> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.value);

  @override
  void didUpdateWidget(covariant _RulerTape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        _controller.hasClients &&
        widget.value != _controller.selectedItem % widget.count) {
      _controller.animateToItem(
        widget.value,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return SizedBox(
      height: 74,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          RotatedBox(
            quarterTurns: -1,
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: 56,
              perspective: 0.0025,
              diameterRatio: 3.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => widget.onChanged(i % widget.count),
              childDelegate: ListWheelChildLoopingListDelegate(
                children: [
                  for (var i = 0; i < widget.count; i++)
                    RotatedBox(
                      quarterTurns: 1,
                      child: _TapeItem(label: _two(i), selected: i == widget.value, t: t),
                    ),
                ],
              ),
            ),
          ),
          // Fixed center indicator over the tick strip.
          IgnorePointer(
            child: Container(
              width: 2.5,
              height: 24,
              decoration: BoxDecoration(
                color: t.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TapeItem extends StatelessWidget {
  const _TapeItem({required this.label, required this.selected, required this.t});

  final String label;
  final bool selected;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CustomPaint(size: const Size(56, 18), painter: _TapeTicksPainter(color: t.border)),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 120),
            style: TextStyle(
              fontSize: selected ? 24 : 15,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? t.headline : t.subhead,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

class _TapeTicksPainter extends CustomPainter {
  _TapeTicksPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    // 4 minor ticks per item; the item's own (center) tick is drawn taller.
    const divisions = 4;
    final step = size.width / divisions;
    for (var i = 0; i <= divisions; i++) {
      final x = i * step;
      final isItemTick = i == divisions ~/ 2;
      final h = isItemTick ? size.height : size.height * 0.55;
      canvas.drawLine(Offset(x, size.height - h), Offset(x, size.height), minor);
    }
  }

  @override
  bool shouldRepaint(covariant _TapeTicksPainter oldDelegate) => oldDelegate.color != color;
}

// --- style 2: arc slider -----------------------------------------------------

class _ArcSliderBody extends StatelessWidget {
  const _ArcSliderBody({
    required this.hour,
    required this.minute,
    required this.onSet,
    required this.t,
  });

  final int hour;
  final int minute;
  final _SetTime onSet;
  final AppPickerTheme t;

  void _bumpMinute(int delta) {
    final total = (hour * 60 + minute + delta) % (24 * 60);
    final wrapped = total < 0 ? total + 24 * 60 : total;
    onSet(hour: wrapped ~/ 60, minute: wrapped % 60);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArcHourSlider(hour: hour, onChanged: (v) => onSet(hour: v), t: t),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            _RoundStepButton(icon: Icons.remove, onPressed: () => _bumpMinute(-1), t: t),
            _TimeReadout(
              hour: hour,
              minute: minute,
              t: t,
              fontSize: 40,
              hourColor: t.primary,
              minuteColor: t.subhead,
            ),
            _RoundStepButton(icon: Icons.add, onPressed: () => _bumpMinute(1), t: t),
          ],
        ),
        const SizedBox(height: 4),
        _MinuteSlider(minute: minute, onChanged: (v) => onSet(minute: v), t: t),
      ],
    );
  }
}

/// Semicircular 0–24h gauge with a draggable knob.
class _ArcHourSlider extends StatelessWidget {
  const _ArcHourSlider({required this.hour, required this.onChanged, required this.t});

  final int hour;
  final ValueChanged<int> onChanged;
  final AppPickerTheme t;

  void _handle(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height - 8);
    final dx = local.dx - center.dx;
    final dy = center.dy - local.dy; // up is positive
    if (dy < -20) return; // ignore touches well below the arc
    final angle = math.atan2(math.max(dy, 0), dx); // 0..pi (right..left)
    final fraction = 1 - angle / math.pi; // left=0 → right=1
    onChanged((fraction * 24).round().clamp(0, 23));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 380.0);
        final size = Size(width, width / 2 + 24);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handle(d.localPosition, size),
          onPanUpdate: (d) => _handle(d.localPosition, size),
          child: CustomPaint(size: size, painter: _ArcPainter(hour: hour, t: t)),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.hour, required this.t});

  final int hour;
  final AppPickerTheme t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 8);
    final radius = size.width / 2 - 36;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = t.border;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = t.primary;

    canvas.drawArc(rect, math.pi, math.pi, false, track);
    final sweep = hour / 24 * math.pi;
    if (sweep > 0) canvas.drawArc(rect, math.pi, sweep, false, progress);

    // Hour labels outside the arc.
    for (final h in const [0, 6, 12, 18, 24]) {
      final angle = math.pi + h / 24 * math.pi;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * (radius + 24);
      final tp = TextPainter(
        text: TextSpan(
          text: '$h',
          style: TextStyle(fontSize: 12, color: t.subhead),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // Knob.
    final knobAngle = math.pi + hour / 24 * math.pi;
    final knobPos = center + Offset(math.cos(knobAngle), math.sin(knobAngle)) * radius;
    canvas.drawCircle(knobPos, 14, Paint()..color = t.background);
    canvas.drawCircle(knobPos, 14, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = t.primary.withValues(alpha: 0.4));
    canvas.drawCircle(knobPos, 9, Paint()..color = t.primary);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.hour != hour || oldDelegate.t != t;
}

// --- style 3: digit pad ------------------------------------------------------

class _DigitPadBody extends StatelessWidget {
  const _DigitPadBody({
    required this.hour,
    required this.minute,
    required this.onSet,
    required this.t,
  });

  final int hour;
  final int minute;
  final _SetTime onSet;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    Widget digitCard(String text, {required bool active}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radius),
          border: Border.all(
            color: active ? t.primary : t.border,
            width: active ? 1.6 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: active ? t.primary : t.headline,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            digitCard(_two(hour), active: true),
            Text(
              ':',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: t.subhead),
            ),
            digitCard(_two(minute), active: false),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var h = 0; h < 24; h++)
              _HourChip(hour: h, selected: h == hour, onTap: () => onSet(hour: h), t: t),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          context.localizations.minute,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.primary),
        ),
        _MinuteSlider(minute: minute, onChanged: (v) => onSet(minute: v), t: t),
      ],
    );
  }
}

class _HourChip extends StatelessWidget {
  const _HourChip({
    required this.hour,
    required this.selected,
    required this.onTap,
    required this.t,
  });

  final int hour;
  final bool selected;
  final VoidCallback onTap;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? t.primary : t.background,
          border: Border.all(color: selected ? t.primary : t.border),
        ),
        child: Text(
          '$hour',
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? t.onPrimary : t.headline,
          ),
        ),
      ),
    );
  }
}

// --- style 4: timeline rail --------------------------------------------------

class _TimelineRailBody extends StatelessWidget {
  const _TimelineRailBody({
    required this.hour,
    required this.minute,
    required this.onSet,
    required this.t,
  });

  final int hour;
  final int minute;
  final _SetTime onSet;
  final AppPickerTheme t;

  void _bumpMinute(int delta) {
    final total = (hour * 60 + minute + delta) % (24 * 60);
    final wrapped = total < 0 ? total + 24 * 60 : total;
    onSet(hour: wrapped ~/ 60, minute: wrapped % 60);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TimelineRail(hour: hour, minute: minute, onChanged: (v) => onSet(hour: v), t: t),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeReadout(
                  hour: hour,
                  minute: minute,
                  t: t,
                  fontSize: 40,
                  hourColor: t.primary,
                  minuteColor: t.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  context.localizations.minute,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.subhead),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var m = 0; m < 60; m += 5)
                      _MinuteChip(
                        minute: m,
                        selected: m == minute,
                        onTap: () => onSet(minute: m),
                        t: t,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 10,
                  children: [
                    _RoundStepButton(
                        icon: Icons.keyboard_arrow_up, onPressed: () => _bumpMinute(1), t: t),
                    _RoundStepButton(
                        icon: Icons.keyboard_arrow_down, onPressed: () => _bumpMinute(-1), t: t),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MinuteChip extends StatelessWidget {
  const _MinuteChip({
    required this.minute,
    required this.selected,
    required this.onTap,
    required this.t,
  });

  final int minute;
  final bool selected;
  final VoidCallback onTap;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 44,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radius),
          color: selected ? t.primary : t.background,
          border: Border.all(color: selected ? t.primary : t.border),
        ),
        child: Text(
          _two(minute),
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? t.onPrimary : t.headline,
          ),
        ),
      ),
    );
  }
}

/// Vertical 00–24 rail with day/night tint and a draggable handle pill.
class _TimelineRail extends StatelessWidget {
  const _TimelineRail({
    required this.hour,
    required this.minute,
    required this.onChanged,
    required this.t,
  });

  final int hour;
  final int minute;
  final ValueChanged<int> onChanged;
  final AppPickerTheme t;

  @override
  Widget build(BuildContext context) {
    const railWidth = 22.0;
    const labelWidth = 40.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        void handle(Offset local) {
          final fraction = (local.dy / height).clamp(0.0, 1.0);
          onChanged((fraction * 24).round().clamp(0, 23));
        }

        final handleY = (hour + minute / 60) / 24 * height;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragDown: (d) => handle(d.localPosition),
          onVerticalDragUpdate: (d) => handle(d.localPosition),
          child: SizedBox(
            width: labelWidth + railWidth + 44,
            child: Stack(
              children: [
                // Hour labels every 3h.
                for (var h = 0; h <= 24; h += 3)
                  Positioned(
                    left: 0,
                    top: (h / 24 * (height - 14)).clamp(0, height - 14),
                    child: SizedBox(
                      width: labelWidth - 6,
                      child: Text(
                        '${_two(h % 24 == 0 && h == 24 ? 24 : h)}:00',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, color: t.subhead),
                      ),
                    ),
                  ),
                // The rail itself with day/night gradient and hour ticks.
                Positioned(
                  left: labelWidth,
                  top: 0,
                  bottom: 0,
                  width: railWidth,
                  child: CustomPaint(painter: _RailPainter(colors: t.railGradient)),
                ),
                // Draggable handle pill.
                Positioned(
                  left: labelWidth - 10,
                  top: (handleY - 14).clamp(0.0, height - 28),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.primary,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${_two(hour)}:${_two(minute)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.onPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width / 2));
    // Night at the edges, warm daylight midday.
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    );
    canvas.drawRRect(rrect, Paint()..shader = gradient.createShader(Offset.zero & size));

    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.2;
    for (var h = 1; h < 24; h++) {
      final y = h / 24 * size.height;
      final long = h % 3 == 0;
      canvas.drawLine(
        Offset(size.width * (long ? 0.15 : 0.3), y),
        Offset(size.width * (long ? 0.85 : 0.7), y),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RailPainter oldDelegate) => oldDelegate.colors != colors;
}

// --- style 5: clock dial -----------------------------------------------------

enum _DialPhase { hour, minute }

/// Analog clock face: 24h dual-ring hour dial (outer 1–12, inner 13–00),
/// then a minute ring. Auto-advances hour → minute after a pick; tapping
/// the readout's hour/minute switches back.
class _ClockDialBody extends StatefulWidget {
  const _ClockDialBody({
    required this.hour,
    required this.minute,
    required this.onSet,
    required this.t,
  });

  final int hour;
  final int minute;
  final _SetTime onSet;
  final AppPickerTheme t;

  @override
  State<_ClockDialBody> createState() => _ClockDialBodyState();
}

class _ClockDialBodyState extends State<_ClockDialBody> {
  _DialPhase _phase = _DialPhase.hour;

  AppPickerTheme get t => widget.t;

  Widget _readoutSegment(String text, {required bool active, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radius),
          color: active ? t.primary.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: active ? t.primary : t.border),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: active ? t.primary : t.headline,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            _readoutSegment(
              _two(widget.hour),
              active: _phase == _DialPhase.hour,
              onTap: () => setState(() => _phase = _DialPhase.hour),
            ),
            Text(
              ':',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: t.subhead),
            ),
            _readoutSegment(
              _two(widget.minute),
              active: _phase == _DialPhase.minute,
              onTap: () => setState(() => _phase = _DialPhase.minute),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ClockDial(
          phase: _phase,
          hour: widget.hour,
          minute: widget.minute,
          t: t,
          onHour: (h) => widget.onSet(hour: h),
          onMinute: (m) => widget.onSet(minute: m),
          onHourPicked: () => setState(() => _phase = _DialPhase.minute),
        ),
      ],
    );
  }
}

class _ClockDial extends StatelessWidget {
  const _ClockDial({
    required this.phase,
    required this.hour,
    required this.minute,
    required this.onHour,
    required this.onMinute,
    required this.onHourPicked,
    required this.t,
  });

  final _DialPhase phase;
  final int hour;
  final int minute;
  final ValueChanged<int> onHour;
  final ValueChanged<int> onMinute;
  final VoidCallback onHourPicked;
  final AppPickerTheme t;

  void _handle(Offset local, double dim, {required bool commit}) {
    final center = Offset(dim / 2, dim / 2);
    final v = local - center;
    final distance = v.distance;
    if (distance < dim * 0.08) return;
    // 12 o'clock is up; angle grows clockwise.
    var angle = math.atan2(v.dx, -v.dy);
    if (angle < 0) angle += 2 * math.pi;

    if (phase == _DialPhase.hour) {
      final slot = (angle / (2 * math.pi) * 12).round() % 12;
      final outerRadius = dim / 2 - 26;
      final innerRadius = dim / 2 - 64;
      final onOuter = (distance - outerRadius).abs() <= (distance - innerRadius).abs();
      // Outer ring: 12,1..11 → 12..23? No: outer = daytime 1..12, inner = 13..00.
      final value = onOuter ? (slot == 0 ? 12 : slot) : (slot == 0 ? 0 : slot + 12);
      onHour(value);
      if (commit) onHourPicked();
    } else {
      final m = (angle / (2 * math.pi) * 60).round() % 60;
      onMinute(m);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dim = math.min(constraints.maxWidth, 300.0);
        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _handle(d.localPosition, dim, commit: false),
            onPanUpdate: (d) => _handle(d.localPosition, dim, commit: false),
            onPanEnd: (_) {
              if (phase == _DialPhase.hour) onHourPicked();
            },
            onTapUp: (d) => _handle(d.localPosition, dim, commit: true),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: CustomPaint(
                key: ValueKey(phase),
                size: Size(dim, dim),
                painter: _ClockDialPainter(
                  phase: phase,
                  hour: hour,
                  minute: minute,
                  t: t,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClockDialPainter extends CustomPainter {
  _ClockDialPainter({
    required this.phase,
    required this.hour,
    required this.minute,
    required this.t,
  });

  final _DialPhase phase;
  final int hour;
  final int minute;
  final AppPickerTheme t;

  void _paintLabel(Canvas canvas, Offset pos, String text, {required bool selected}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          color: selected ? t.onPrimary : t.headline,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  Offset _slotPos(Offset center, double radius, int slot, int slots) {
    final angle = slot / slots * 2 * math.pi - math.pi / 2;
    return center + Offset(math.cos(angle), math.sin(angle)) * radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final faceRadius = size.width / 2;
    final outerRadius = faceRadius - 26;
    final innerRadius = faceRadius - 64;

    canvas.drawCircle(center, faceRadius, Paint()..color = t.border.withValues(alpha: 0.35));

    Offset handTarget;
    if (phase == _DialPhase.hour) {
      final slot = hour % 12;
      final onOuter = hour >= 1 && hour <= 12;
      handTarget = _slotPos(center, onOuter ? outerRadius : innerRadius, slot, 12);
    } else {
      handTarget = _slotPos(center, outerRadius, minute, 60);
    }

    // Hand + selection puck under the labels.
    canvas.drawLine(
      center,
      handTarget,
      Paint()
        ..color = t.primary
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 5, Paint()..color = t.primary);
    canvas.drawCircle(handTarget, 18, Paint()..color = t.primary);

    if (phase == _DialPhase.hour) {
      for (var slot = 0; slot < 12; slot++) {
        final outerValue = slot == 0 ? 12 : slot;
        final innerValue = slot == 0 ? 0 : slot + 12;
        _paintLabel(
          canvas,
          _slotPos(center, outerRadius, slot, 12),
          '$outerValue',
          selected: hour == outerValue,
        );
        _paintLabel(
          canvas,
          _slotPos(center, innerRadius, slot, 12),
          _two(innerValue),
          selected: hour == innerValue,
        );
      }
    } else {
      for (var m = 0; m < 60; m += 5) {
        _paintLabel(
          canvas,
          _slotPos(center, outerRadius, m, 60),
          _two(m),
          selected: minute == m,
        );
      }
      // Minute ticks between labels.
      final tick = Paint()
        ..color = t.subhead.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (var m = 0; m < 60; m++) {
        if (m % 5 == 0) continue;
        final pos = _slotPos(center, faceRadius - 8, m, 60);
        final pos2 = _slotPos(center, faceRadius - 13, m, 60);
        canvas.drawLine(pos, pos2, tick);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClockDialPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.hour != hour ||
      oldDelegate.minute != minute ||
      oldDelegate.t != t;
}
