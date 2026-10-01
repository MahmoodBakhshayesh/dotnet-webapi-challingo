import 'package:challingo/core/theme/app_colors.dart';
import 'package:challingo/widgets/inputs/challingo_field_decoration.dart';
import 'package:flutter/material.dart';
import 'package:unified_fields/unified_fields.dart';

/// App-wide [UnifiedInputThemeScope] for forms, pickers, and sheets.
class UnifiedInputThemeShell extends StatelessWidget {
  final Widget child;

  const UnifiedInputThemeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return UnifiedInputThemeScope(
      data: _themeData,
      brightnessOverride: UnifiedInputBrightness.light,
      paletteOverride: _palette,
      child: child,
    );
  }

  static final UnifiedInputThemeData _themeData = UnifiedInputThemeData(
    disabledFieldBackgroundOpacity: 0.5,
    fieldDefaults: UnifiedInputFieldDefaults(
      labelMode: UnifiedFieldLabelMode.labelInColumn,
      height: ChallingoFieldDecoration.singleLineHeight,
      borderSide: ChallingoFieldDecoration.defaultBorder,
      borderRadius: BorderRadius.circular(6),
      textStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 14,
        color: AppColors.textColor,
      ),
      textStylePersian: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 14,
        color: AppColors.textColor,
      ),
      placeholderStyle: const TextStyle(
        fontFamily: 'Nunito',
        color: Color(0xffC4C4C4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    fieldDecorationSet: ChallingoFieldDecoration.decorationSet,
    multiPickerCheckboxStyle: const UnifiedInputMultiPickerCheckboxStyle(
      borderColor: AppColors.borderColor2,
    ),
    pickerHeaderStyle: const UnifiedInputPickerHeaderStyle(
      titleStyle: TextStyle(
        color: AppColors.textColor,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'Nunito',
      ),
      padding: EdgeInsets.only(left: 12, right: 16, top: 12, bottom: 8),
    ),
    pickerSheetBackgroundColor: AppColors.cardColor,
  );

  static final UnifiedInputPalette _palette = UnifiedInputPalette(
    bodyBackground: AppColors.cardColor,
    headerBackground: AppColors.scaffoldHeader,
    labelColor: AppColors.textColor,
    hintColor: AppColors.subheadColor,
    fieldTextColor: AppColors.textColor,
    borderColor: AppColors.borderColor,
    defaultBorderSide: ChallingoFieldDecoration.defaultBorder,
    borderRadius: BorderRadius.circular(8),
    validationColor: AppColors.errorColor,
    sheetBackground: AppColors.cardColor,
    sheetHeaderBackground: AppColors.scaffoldHeader,
  );
}
