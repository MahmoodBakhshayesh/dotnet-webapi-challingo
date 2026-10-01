/// Invoked when a comment author's avatar/name is tapped.
typedef UserProfileTapCallback = void Function(String userId, String? userName);

/// UI model for a single comment (supports nested replies).
///
/// Map your feature's comment entity into this model in the feature layer
/// (e.g. a `CommentSectionItem.fromX` extension next to the entity).
class CommentSectionItem {
  const CommentSectionItem({
    required this.id,
    required this.displayName,
    required this.body,
    required this.createdAt,
    this.userId = '',
    this.userName,
    this.roleLabel,
    this.avatarUrl,
    this.likeCount = 0,
    this.replyCount = 0,
    this.isLiked = false,
    this.replies = const [],
    this.hiddenReplyCount = 0,
    this.repliesExpanded = false,
  });

  final String id;
  final String displayName;
  final String body;
  final DateTime createdAt;
  final String userId;
  final String? userName;
  final String? roleLabel;
  final String? avatarUrl;
  final int likeCount;
  final int replyCount;
  final bool isLiked;
  final List<CommentSectionItem> replies;

  /// Replies not yet loaded/shown — drives "view N replies".
  final int hiddenReplyCount;
  final bool repliesExpanded;

  int get totalReplyCount => replies.length + hiddenReplyCount;

  bool get hasReplies => replyCount > 0 || replies.isNotEmpty;

  CommentSectionItem copyWith({
    String? id,
    String? displayName,
    String? body,
    DateTime? createdAt,
    String? userId,
    String? userName,
    String? roleLabel,
    String? avatarUrl,
    int? likeCount,
    int? replyCount,
    bool? isLiked,
    List<CommentSectionItem>? replies,
    int? hiddenReplyCount,
    bool? repliesExpanded,
  }) {
    return CommentSectionItem(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      roleLabel: roleLabel ?? this.roleLabel,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      isLiked: isLiked ?? this.isLiked,
      replies: replies ?? this.replies,
      hiddenReplyCount: hiddenReplyCount ?? this.hiddenReplyCount,
      repliesExpanded: repliesExpanded ?? this.repliesExpanded,
    );
  }
}
