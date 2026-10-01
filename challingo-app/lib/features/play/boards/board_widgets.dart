import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Row(s) of big digit keys plus an erase key.
class DigitPad extends StatelessWidget {
  const DigitPad({super.key, required this.digits, required this.onDigit, required this.onErase, this.enabled = true});

  final List<int> digits;
  final ValueChanged<int> onDigit;
  final VoidCallback onErase;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Up to 6 digits fit one row (erase below); 1–9 go 5 + 4 with erase closing the second row.
    final perRow = digits.length <= 6 ? digits.length : 5;
    final rows = <List<int?>>[
      for (var i = 0; i < digits.length; i += perRow) <int?>[...digits.sublist(i, (i + perRow).clamp(0, digits.length))],
    ];
    final eraseOnOwnRow = digits.length <= 6;
    if (!eraseOnOwnRow) rows.last.add(null);

    Widget key(Widget child, VoidCallback onTap, {String? label}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Semantics(
          button: true,
          label: label,
          // White key on a solid bottom shadow (the shadow must sit under an opaque fill).
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: enabled ? onTap : null,
                child: SizedBox(height: 58, child: Center(child: child)),
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(children: [
            for (final d in row)
              d == null
                  ? key(const Icon(Icons.backspace_outlined, color: AppColors.ink), onErase, label: 'Erase')
                  : key(Text('$d', style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w600, fontSize: 28, color: AppColors.violet)), () => onDigit(d)),
          ]),
        if (eraseOnOwnRow)
          Row(children: [const Spacer(flex: 2), key(const Icon(Icons.backspace_outlined, color: AppColors.ink), onErase, label: 'Erase'), const Spacer(flex: 2)]),
      ],
    );
  }
}

/// QWERTY keyboard for the word games; [marks] colours keys ("correct"/"present"/"absent").
class LetterKeyboard extends StatelessWidget {
  const LetterKeyboard({super.key, required this.onLetter, required this.onBackspace, this.onEnter, this.marks = const {}, this.enabled = true});

  final ValueChanged<String> onLetter;
  final VoidCallback onBackspace;
  final VoidCallback? onEnter;
  final Map<String, String> marks;
  final bool enabled;

  static const _rows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onTap, {int flex = 2, Color? bg, Color fg = AppColors.ink, Widget? child}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 4),
        child: Material(
          color: bg ?? Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              height: 52,
              child: Center(child: child ?? Text(label.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: fg))),
            ),
          ),
        ),
      ),
    );

    Color? markColor(String letter) => switch (marks[letter]) {
      'correct' => AppColors.mint,
      'present' => AppColors.sun,
      'absent' => AppColors.inkMuted,
      _ => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, row) in _rows.indexed)
          Row(children: [
            if (i == 1) const Spacer(),
            if (i == 2 && onEnter != null)
              key('', onEnter!, flex: 3, bg: AppColors.violet, child: const Icon(Icons.keyboard_return_rounded, color: Colors.white, semanticLabel: 'Enter')),
            for (final c in row.split(''))
              key(c, () => onLetter(c), bg: markColor(c), fg: marks[c] == null || marks[c] == 'present' ? AppColors.ink : Colors.white),
            if (i == 2) key('', onBackspace, flex: 3, child: const Icon(Icons.backspace_outlined, size: 20, color: AppColors.ink, semanticLabel: 'Delete')),
            if (i == 1) const Spacer(),
          ]),
      ],
    );
  }
}

/// Small rounded tool button (Erase, Check, Mode…).
class ToolChip extends StatelessWidget {
  const ToolChip({super.key, required this.icon, required this.label, required this.onTap, this.selected = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.ink : Colors.white,
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: selected ? Colors.white : AppColors.ink),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: selected ? Colors.white : AppColors.ink)),
        ]),
      ),
    ),
  );
}

/// Square board frame used by every grid game.
class BoardFrame extends StatelessWidget {
  const BoardFrame({super.key, required this.child, this.aspectRatio = 1});

  final Widget child;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}

List<int> intList(Object? json) => (json as List).map((e) => (e as num).toInt()).toList();
