import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/extensions/date_time_extension.dart';
import '../authenticated_media_image.dart';
import 'comment_section_models.dart';
import 'comment_section_style.dart';

export 'comment_section_models.dart';
export 'comment_section_style.dart';

/// Formats a comment's [DateTime] into a display string (e.g. "5m ago").
typedef CommentTimeFormatter = String Function(DateTime createdAt);

/// Builds the "View N replies" label from the reply [count].
typedef ViewRepliesLabelBuilder = String Function(int count);

/// Comment list + composer with animated likes, replies, and thread expansion.
class CommentSection extends StatefulWidget {
  const CommentSection({
    super.key,
    required this.comments,
    this.currentUserAvatarUrl,
    this.style = const CommentSectionStyle(),
    this.showComposer = true,
    this.composerPlaceholder,
    this.replyLabel,
    this.viewRepliesLabelBuilder,
    this.hideRepliesLabel,
    this.timeFormatter,
    this.onLike,
    this.onPostComment,
    this.onPostReply,
    this.onViewReplies,
    this.onHideReplies,
    this.onReplyTap,
    this.onUserProfileTap,
    this.isPosting = false,
  });

  final List<CommentSectionItem> comments;
  final String? currentUserAvatarUrl;
  final CommentSectionStyle style;
  final bool showComposer;
  final String? composerPlaceholder;
  final String? replyLabel;
  final ViewRepliesLabelBuilder? viewRepliesLabelBuilder;
  final String? hideRepliesLabel;
  final CommentTimeFormatter? timeFormatter;
  final ValueChanged<CommentSectionItem>? onLike;
  final Future<void> Function(String text)? onPostComment;
  final Future<void> Function(String parentId, String text)? onPostReply;
  final ValueChanged<CommentSectionItem>? onViewReplies;
  final ValueChanged<CommentSectionItem>? onHideReplies;
  final ValueChanged<CommentSectionItem>? onReplyTap;
  final UserProfileTapCallback? onUserProfileTap;
  final bool isPosting;

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  String? _replyingToId;
  final _replyControllers = <String, TextEditingController>{};
  final _replyFocusNodes = <String, FocusNode>{};

  @override
  void dispose() {
    _composerController.dispose();
    _composerFocus.dispose();
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    for (final f in _replyFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  String _timeLabel(DateTime createdAt) =>
      widget.timeFormatter?.call(createdAt) ?? createdAt.getUntilNowMessage();

  String _viewRepliesLabel(int count) =>
      widget.viewRepliesLabelBuilder?.call(count) ?? 'View $count replies';

  TextEditingController _replyControllerFor(String id) =>
      _replyControllers.putIfAbsent(id, TextEditingController.new);

  FocusNode _replyFocusFor(String id) =>
      _replyFocusNodes.putIfAbsent(id, FocusNode.new);

  void _startReply(CommentSectionItem comment) {
    widget.onReplyTap?.call(comment);
    setState(() => _replyingToId = comment.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _replyFocusFor(comment.id).requestFocus();
    });
  }

  void _cancelReply() {
    final id = _replyingToId;
    setState(() => _replyingToId = null);
    if (id != null) {
      _replyControllerFor(id).clear();
      _replyFocusFor(id).unfocus();
    }
  }

  Future<void> _submitMainComment() async {
    final text = _composerController.text.trim();
    if (text.isEmpty || widget.onPostComment == null) return;
    await widget.onPostComment!(text);
    if (!mounted) return;
    _composerController.clear();
    _composerFocus.unfocus();
  }

  Future<void> _submitReply(String parentId) async {
    final text = _replyControllerFor(parentId).text.trim();
    if (text.isEmpty || widget.onPostReply == null) return;
    await widget.onPostReply!(parentId, text);
    if (!mounted) return;
    _replyControllerFor(parentId).clear();
    setState(() => _replyingToId = null);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final replyLabel = widget.replyLabel ?? 'Reply';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...widget.comments.map(
          (comment) => Padding(
            padding: EdgeInsets.only(bottom: style.commentSpacing),
            child: _AnimatedCommentEntrance(
              key: ValueKey(comment.id),
              child: _CommentThread(
                comment: comment,
                style: style,
                depth: 0,
                replyLabel: replyLabel,
                replyingToId: _replyingToId,
                timeLabel: _timeLabel,
                viewRepliesLabel: _viewRepliesLabel,
                hideRepliesLabel: widget.hideRepliesLabel ?? 'Hide replies',
                onLike: widget.onLike,
                onReply: _startReply,
                onViewReplies: widget.onViewReplies,
                onHideReplies: widget.onHideReplies,
                onCancelReply: _cancelReply,
                onSubmitReply: widget.onPostReply == null ? null : _submitReply,
                replyControllerFor: _replyControllerFor,
                replyFocusFor: _replyFocusFor,
                composerPlaceholder:
                    widget.composerPlaceholder ?? 'Write your comment...',
                isPosting: widget.isPosting,
                onUserProfileTap: widget.onUserProfileTap,
              ),
            ),
          ),
        ),
        if (widget.showComposer) ...[
          SizedBox(height: style.commentSpacing / 2),
          _CommentComposer(
            avatarUrl: widget.currentUserAvatarUrl,
            controller: _composerController,
            focusNode: _composerFocus,
            style: style,
            placeholder: widget.composerPlaceholder ?? 'Write your comment...',
            onSubmit: widget.onPostComment == null ? null : _submitMainComment,
            isPosting: widget.isPosting,
          ),
        ],
      ],
    );
  }
}

class _CommentThread extends StatelessWidget {
  const _CommentThread({
    required this.comment,
    required this.style,
    required this.depth,
    required this.replyLabel,
    required this.replyingToId,
    required this.timeLabel,
    required this.viewRepliesLabel,
    required this.hideRepliesLabel,
    required this.onReply,
    required this.onCancelReply,
    this.onLike,
    this.onViewReplies,
    this.onHideReplies,
    this.onSubmitReply,
    required this.replyControllerFor,
    required this.replyFocusFor,
    required this.composerPlaceholder,
    required this.isPosting,
    this.onUserProfileTap,
  });

  final CommentSectionItem comment;
  final CommentSectionStyle style;
  final int depth;
  final String replyLabel;
  final String hideRepliesLabel;
  final String? replyingToId;
  final String Function(DateTime) timeLabel;
  final String Function(int) viewRepliesLabel;
  final ValueChanged<CommentSectionItem>? onLike;
  final ValueChanged<CommentSectionItem> onReply;
  final ValueChanged<CommentSectionItem>? onViewReplies;
  final ValueChanged<CommentSectionItem>? onHideReplies;
  final VoidCallback onCancelReply;
  final Future<void> Function(String parentId)? onSubmitReply;
  final TextEditingController Function(String id) replyControllerFor;
  final FocusNode Function(String id) replyFocusFor;
  final String composerPlaceholder;
  final bool isPosting;
  final UserProfileTapCallback? onUserProfileTap;

  @override
  Widget build(BuildContext context) {
    final isReplying = replyingToId == comment.id;
    final hasLoadedReplies = comment.replies.isNotEmpty;
    final showReplyThread = comment.repliesExpanded && hasLoadedReplies;
    final hiddenCount = comment.repliesExpanded
        ? comment.hiddenReplyCount
        : comment.replyCount;

    final replyChildren = <Widget>[
      for (var i = 0; i < comment.replies.length; i++)
        Padding(
          padding: EdgeInsets.only(
            top: i == 0 ? 0 : style.commentSpacing * 0.65,
          ),
          child: _AnimatedCommentEntrance(
            key: ValueKey(comment.replies[i].id),
            child: _CommentThread(
              comment: comment.replies[i],
              style: style,
              depth: depth + 1,
              replyLabel: replyLabel,
              hideRepliesLabel: hideRepliesLabel,
              replyingToId: replyingToId,
              timeLabel: timeLabel,
              viewRepliesLabel: viewRepliesLabel,
              onLike: onLike,
              onReply: onReply,
              onViewReplies: onViewReplies,
              onHideReplies: onHideReplies,
              onCancelReply: onCancelReply,
              onSubmitReply: onSubmitReply,
              replyControllerFor: replyControllerFor,
              replyFocusFor: replyFocusFor,
              composerPlaceholder: composerPlaceholder,
              isPosting: isPosting,
              onUserProfileTap: onUserProfileTap,
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CommentTile(
          comment: comment,
          style: style,
          depth: depth,
          timeLabel: timeLabel(comment.createdAt),
          replyLabel: replyLabel,
          onLike: onLike,
          onReply: () => onReply(comment),
          onViewReplies: depth == 0 ? onViewReplies : null,
          onUserProfileTap: onUserProfileTap,
        ),
        _AnimatedReplyComposer(
          visible: isReplying,
          style: style,
          child: _CommentComposer(
            avatarUrl: null,
            controller: replyControllerFor(comment.id),
            focusNode: replyFocusFor(comment.id),
            style: style,
            placeholder: composerPlaceholder,
            onSubmit: onSubmitReply == null
                ? null
                : () => onSubmitReply!(comment.id),
            onCancel: onCancelReply,
            isPosting: isPosting,
            compact: true,
          ),
        ),
        if (comment.hasReplies && !showReplyThread)
          _ThreadActionRow(
            label: viewRepliesLabel(hiddenCount),
            style: style,
            onTap: () => onViewReplies?.call(comment),
          ),
        _AnimatedRepliesBlock(
          visible: showReplyThread,
          style: style,
          threadKey: 'replies-${comment.id}',
          child: depth == 0
              ? _ReplyThreadRail(
                  style: style,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: replyChildren,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: replyChildren,
                ),
        ),
        if (showReplyThread && depth == 0)
          _ThreadActionRow(
            label: hideRepliesLabel,
            style: style,
            onTap: () => onHideReplies?.call(comment),
          ),
        if (comment.repliesExpanded && comment.hiddenReplyCount > 0 && showReplyThread)
          _ThreadActionRow(
            label: viewRepliesLabel(comment.hiddenReplyCount),
            style: style,
            onTap: () => onViewReplies?.call(comment),
          ),
      ],
    );
  }
}

/// Vertical rail linking replies to the parent comment avatar.
class _ReplyThreadRail extends StatelessWidget {
  const _ReplyThreadRail({
    required this.style,
    required this.child,
  });

  final CommentSectionStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lineWidth = style.threadLineWidth;

    return Padding(
      padding: EdgeInsets.only(top: style.commentSpacing * 0.35),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: 8,
            top: 0,
            bottom: 0,
            child: Container(
              width: lineWidth,
              decoration: BoxDecoration(
                color: style.threadLineColor,
                borderRadius: BorderRadius.circular(lineWidth),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.style,
    required this.depth,
    required this.timeLabel,
    required this.replyLabel,
    this.onLike,
    this.onReply,
    this.onViewReplies,
    this.onUserProfileTap,
  });

  final CommentSectionItem comment;
  final CommentSectionStyle style;
  final int depth;
  final String timeLabel;
  final String replyLabel;
  final ValueChanged<CommentSectionItem>? onLike;
  final VoidCallback? onReply;
  final ValueChanged<CommentSectionItem>? onViewReplies;
  final UserProfileTapCallback? onUserProfileTap;

  void _openProfile() {
    if (comment.userId.isEmpty) return;
    onUserProfileTap?.call(comment.userId, comment.userName);
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = depth == 0 ? style.avatarSize : style.replyAvatarSize;

    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 12,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onUserProfileTap == null ? null : _openProfile,
              child: _CommentAvatar(
                url: comment.avatarUrl,
                size: avatarSize,
                fallbackColor: style.unlikedColor,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: onUserProfileTap == null ? null : _openProfile,
                          child: Text(
                            comment.displayName,
                            style: style.resolvedNameStyle(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(timeLabel, style: style.resolvedTimeStyle(context)),
                    ],
                  ),
                  if (comment.roleLabel != null && comment.roleLabel!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      comment.roleLabel!,
                      style: style.resolvedRoleStyle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            _CommentEngagementColumn(
              isLiked: comment.isLiked,
              likeCount: comment.likeCount,
              replyCount: comment.replyCount,
              style: style,
              onLike: onLike == null ? null : () => onLike!(comment),
              onReplyCountTap: comment.replyCount > 0 && onViewReplies != null
                  ? () => onViewReplies!(comment)
                  : null,
            ),
          ],
        ),
        Text(
          comment.body,
          style: style.resolvedBodyStyle(context).copyWith(height: 1.55),
        ),
        if (depth == 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _ReplyActionButton(
              label: replyLabel,
              style: style,
              onTap: onReply,
            ),
          ),
      ],
    );
  }
}

class _ReplyActionButton extends StatefulWidget {
  const _ReplyActionButton({
    required this.label,
    required this.style,
    this.onTap,
  });

  final String label;
  final CommentSectionStyle style;
  final VoidCallback? onTap;

  @override
  State<_ReplyActionButton> createState() => _ReplyActionButtonState();
}

class _ReplyActionButtonState extends State<_ReplyActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.72 : 1,
          duration: const Duration(milliseconds: 120),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              widget.label,
              style: widget.style.resolvedActionStyle(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentEngagementColumn extends StatelessWidget {
  const _CommentEngagementColumn({
    required this.isLiked,
    required this.likeCount,
    required this.replyCount,
    required this.style,
    this.onLike,
    this.onReplyCountTap,
  });

  final bool isLiked;
  final int likeCount;
  final int replyCount;
  final CommentSectionStyle style;
  final VoidCallback? onLike;
  final VoidCallback? onReplyCountTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CommentReplyCount(
          count: replyCount,
          style: style,
          onTap: onReplyCountTap,
        ),
        _CommentLikeButton(
          isLiked: isLiked,
          likeCount: likeCount,
          style: style,
          onTap: onLike,
        ),
      ],
    );
  }
}

class _CommentReplyCount extends StatelessWidget {
  const _CommentReplyCount({
    required this.count,
    required this.style,
    this.onTap,
  });

  final int count;
  final CommentSectionStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 28,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reply, color: style.unlikedColor, size: 20),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: style.resolvedLikeCountStyle(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentLikeButton extends StatefulWidget {
  const _CommentLikeButton({
    required this.isLiked,
    required this.likeCount,
    required this.style,
    this.onTap,
  });

  final bool isLiked;
  final int likeCount;
  final CommentSectionStyle style;
  final VoidCallback? onTap;

  @override
  State<_CommentLikeButton> createState() => _CommentLikeButtonState();
}

class _CommentLikeButtonState extends State<_CommentLikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.style.likeAnimationDuration,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant _CommentLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLiked && widget.isLiked) {
      _controller
        ..stop()
        ..forward(from: 0);
      HapticFeedback.lightImpact();
    } else if (oldWidget.isLiked && !widget.isLiked) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isLiked ? widget.style.likedColor : widget.style.unlikedColor;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 36,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: AnimatedSwitcher(
                duration: widget.style.animationDuration,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  widget.isLiked ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(widget.isLiked),
                  size: 22,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: widget.style.animationDuration,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                '${widget.likeCount}',
                key: ValueKey(widget.likeCount),
                style: widget.style.resolvedLikeCountStyle(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadActionRow extends StatelessWidget {
  const _ThreadActionRow({
    required this.label,
    required this.style,
    this.onTap,
  });

  final String label;
  final CommentSectionStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: style.commentSpacing * 0.45),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                height: 0.5,
                width: 24,
                color: style.threadLineColor,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: style
                    .resolvedViewRepliesStyle(context)
                    .copyWith(color: style.threadLineColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentComposer extends StatefulWidget {
  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.placeholder,
    this.avatarUrl,
    this.onSubmit,
    this.onCancel,
    this.isPosting = false,
    this.compact = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final CommentSectionStyle style;
  final String placeholder;
  final String? avatarUrl;
  final Future<void> Function()? onSubmit;
  final VoidCallback? onCancel;
  final bool isPosting;
  final bool compact;

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _CommentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final style = widget.style;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!widget.compact) ...[
          _CommentAvatar(
            url: widget.avatarUrl,
            size: style.avatarSize,
            fallbackColor: style.unlikedColor,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: AnimatedContainer(
            duration: style.animationDuration,
            curve: Curves.easeOutCubic,
            height: style.composerHeight,
            decoration: BoxDecoration(
              color: style.composerBackgroundColor,
              borderRadius: BorderRadius.circular(style.composerRadius),
              border: widget.focusNode.hasFocus
                  ? Border.all(color: style.likedColor.withValues(alpha: 0.45))
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    enabled: !widget.isPosting,
                    style: style.resolvedComposerTextStyle(context),
                    decoration: InputDecoration(
                      hintText: widget.placeholder,
                      hintStyle: style.resolvedComposerHintStyle(context),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted:
                        widget.onSubmit == null ? null : (_) => widget.onSubmit!(),
                  ),
                ),
                if (widget.onSubmit != null)
                  _ComposerSendButton(
                    isPosting: widget.isPosting,
                    color: style.unlikedColor,
                    onTap: widget.onSubmit,
                  ),
                if (widget.compact && widget.onCancel != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, size: 18),
                    color: style.unlikedColor,
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ComposerSendButton extends StatefulWidget {
  const _ComposerSendButton({
    required this.isPosting,
    required this.color,
    this.onTap,
  });

  final bool isPosting;
  final Color color;
  final Future<void> Function()? onTap;

  @override
  State<_ComposerSendButton> createState() => _ComposerSendButtonState();
}

class _ComposerSendButtonState extends State<_ComposerSendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isPosting ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.isPosting ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.isPosting ? null : () => setState(() => _pressed = false),
      onTap: widget.isPosting ? null : widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 120),
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: widget.isPosting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.send_rounded, size: 22, color: widget.color),
        ),
      ),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({
    this.url,
    required this.size,
    required this.fallbackColor,
  });

  final String? url;
  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return AuthenticatedMediaAvatar(
      url: url,
      size: size,
      fit: BoxFit.cover,
      fallback: Icon(Icons.person, size: size * 0.42, color: fallbackColor),
    );
  }
}

class _AnimatedCommentEntrance extends StatefulWidget {
  const _AnimatedCommentEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<_AnimatedCommentEntrance> createState() =>
      _AnimatedCommentEntranceState();
}

class _AnimatedCommentEntranceState extends State<_AnimatedCommentEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _AnimatedRepliesBlock extends StatelessWidget {
  const _AnimatedRepliesBlock({
    required this.visible,
    required this.style,
    required this.child,
    required this.threadKey,
  });

  final bool visible;
  final CommentSectionStyle style;
  final Widget child;
  final String threadKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: style.animationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: style.animationDuration,
        curve: Curves.easeOutCubic,
        opacity: visible ? 1 : 0,
        child: visible
            ? KeyedSubtree(key: ValueKey(threadKey), child: child)
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _AnimatedReplyComposer extends StatelessWidget {
  const _AnimatedReplyComposer({
    required this.visible,
    required this.style,
    required this.child,
  });

  final bool visible;
  final CommentSectionStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: style.animationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: style.animationDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: visible
            ? Padding(
                key: const ValueKey('reply-composer'),
                padding: EdgeInsets.only(
                  top: style.commentSpacing * 0.45,
                  right: style.replyIndent,
                ),
                child: child,
              )
            : const SizedBox.shrink(key: ValueKey('no-reply-composer')),
      ),
    );
  }
}
