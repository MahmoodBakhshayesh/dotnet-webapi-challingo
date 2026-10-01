import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Visual configuration for `CommentSection` (colors, text styles, avatar
/// size, composer chrome); defaults use the app's `AppColors` tokens.
class CommentSectionStyle {
  const CommentSectionStyle({
    this.avatarSize = 48,
    this.replyAvatarSize = 40,
    this.commentSpacing = 16,
    this.replyIndent = 20,
    this.threadLineWidth = 0.5,
    this.threadLineColor = AppColors.primaryColor,
    this.replyThreadSpacing = 0,
    this.composerHeight = 48,
    this.composerRadius = 16,
    this.composerBackgroundColor = AppColors.borderColor1,
    this.dividerColor = AppColors.borderColor1,
    this.nameStyle,
    this.timeStyle,
    this.roleStyle,
    this.bodyStyle,
    this.actionStyle,
    this.likeCountStyle,
    this.viewRepliesStyle,
    this.composerTextStyle,
    this.composerHintStyle,
    this.likedColor = AppColors.primaryColor,
    this.unlikedColor = AppColors.subheadColor,
    this.animationDuration = const Duration(milliseconds: 320),
    this.likeAnimationDuration = const Duration(milliseconds: 420),
  });

  final double avatarSize;
  final double replyAvatarSize;
  final double commentSpacing;
  final double replyIndent;
  final double threadLineWidth;
  final Color threadLineColor;
  final double replyThreadSpacing;
  final double composerHeight;
  final double composerRadius;
  final Color composerBackgroundColor;
  final Color dividerColor;
  final TextStyle? nameStyle;
  final TextStyle? timeStyle;
  final TextStyle? roleStyle;
  final TextStyle? bodyStyle;
  final TextStyle? actionStyle;
  final TextStyle? likeCountStyle;
  final TextStyle? viewRepliesStyle;
  final TextStyle? composerTextStyle;
  final TextStyle? composerHintStyle;
  final Color likedColor;
  final Color unlikedColor;
  final Duration animationDuration;
  final Duration likeAnimationDuration;

  TextStyle resolvedNameStyle(BuildContext context) =>
      nameStyle ??
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textColor);

  TextStyle resolvedTimeStyle(BuildContext context) =>
      timeStyle ?? const TextStyle(fontSize: 12, color: AppColors.subheadColor);

  TextStyle resolvedRoleStyle(BuildContext context) =>
      roleStyle ?? const TextStyle(fontSize: 12, color: AppColors.subheadColor);

  TextStyle resolvedBodyStyle(BuildContext context) =>
      bodyStyle ?? const TextStyle(fontSize: 14, color: AppColors.textColor);

  TextStyle resolvedActionStyle(BuildContext context) =>
      actionStyle ?? const TextStyle(fontSize: 14, color: AppColors.subheadColor);

  TextStyle resolvedLikeCountStyle(BuildContext context) =>
      likeCountStyle ?? const TextStyle(fontSize: 12, color: AppColors.subheadColor);

  TextStyle resolvedViewRepliesStyle(BuildContext context) =>
      viewRepliesStyle ?? const TextStyle(fontSize: 12, color: AppColors.subheadColor);

  TextStyle resolvedComposerTextStyle(BuildContext context) =>
      composerTextStyle ?? const TextStyle(fontSize: 14, color: AppColors.textColor);

  TextStyle resolvedComposerHintStyle(BuildContext context) =>
      composerHintStyle ?? const TextStyle(fontSize: 14, color: AppColors.subheadColor);
}
