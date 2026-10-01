/// Typed views of the competition endpoints (`/competition`, `/groups`). Enums arrive as ints.
library;

import 'api_models.dart';

DateTime _date(Object? v) => DateTime.parse(v as String).toUtc();
int _int(Object? v) => (v as num).toInt();
Map<String, dynamic> _map(Object? v) => (v as Map).cast<String, dynamic>();

/// Matches the API's ChallengeKind.
enum ChallengeKind { practice, daily, ranked, grand }

/// Matches the API's ChallengeState.
enum ChallengeState { upcoming, open, closed }

/// Matches the API's BoardPeriod.
enum BoardPeriod { round, day, week, grand, allTime }

/// Matches the API's BoardScope.
enum BoardScope { global, country, group }

class Standing {
  const Standing({required this.rank, required this.players, required this.provisionalPoints});

  final int rank;
  final int players;

  /// Points if the round closed now.
  final int provisionalPoints;

  static Standing? fromJson(Object? json) {
    if (json is! Map) return null;
    return Standing(rank: _int(json['rank']), players: _int(json['players']), provisionalPoints: _int(json['provisionalPoints']));
  }
}

class MyAttempt {
  const MyAttempt({required this.status, required this.elapsedMs, required this.points, required this.rank, required this.countsForDay});

  final AttemptStatus status;
  final int? elapsedMs;
  final int? points;
  final int? rank;
  final bool countsForDay;

  bool get finished => status != AttemptStatus.inProgress;

  factory MyAttempt.fromJson(Map<String, dynamic> json) => MyAttempt(
    status: AttemptStatus.values[_int(json['status'])],
    elapsedMs: (json['elapsedMs'] as num?)?.toInt(),
    points: (json['points'] as num?)?.toInt(),
    rank: (json['rank'] as num?)?.toInt(),
    countsForDay: json['countsForDay'] as bool? ?? false,
  );
}

class ChallengeCard {
  const ChallengeCard({
    required this.challengeId,
    required this.kind,
    required this.sequence,
    required this.gameKey,
    required this.opensAtUtc,
    required this.closesAtUtc,
    required this.state,
    required this.finalized,
    required this.my,
  });

  final String challengeId;
  final ChallengeKind kind;
  final int sequence;

  /// Null while a ranked round is more than one round away.
  final String? gameKey;
  final DateTime opensAtUtc;
  final DateTime closesAtUtc;
  final ChallengeState state;
  final bool finalized;
  final MyAttempt? my;

  /// Open or upcoming/closed, judged against server time (the state from the API ages).
  ChallengeState stateAt(DateTime serverNow) => serverNow.isBefore(opensAtUtc)
      ? ChallengeState.upcoming
      : serverNow.isBefore(closesAtUtc)
      ? ChallengeState.open
      : ChallengeState.closed;

  factory ChallengeCard.fromJson(Map<String, dynamic> json) => ChallengeCard(
    challengeId: json['challengeId'] as String,
    kind: ChallengeKind.values[_int(json['kind'])],
    sequence: _int(json['sequence']),
    gameKey: json['gameKey'] as String?,
    opensAtUtc: _date(json['opensAtUtc']),
    closesAtUtc: _date(json['closesAtUtc']),
    state: ChallengeState.values[_int(json['state'])],
    finalized: json['finalized'] as bool? ?? false,
    my: json['my'] == null ? null : MyAttempt.fromJson(_map(json['my'])),
  );
}

class Today {
  const Today({
    required this.serverNowUtc,
    required this.utcDate,
    required this.localDate,
    required this.weekKey,
    required this.isGrandDay,
    required this.rounds,
    required this.nextRound,
    required this.daily,
    required this.grand,
    required this.featured,
    required this.rankedUsed,
    required this.rankedAllowed,
    required this.stars,
  });

  final DateTime serverNowUtc;
  final String utcDate;
  final String localDate;
  final String weekKey;
  final bool isGrandDay;
  final List<ChallengeCard> rounds;
  final ChallengeCard? nextRound;
  final ChallengeCard? daily;
  final List<ChallengeCard> grand;

  /// Mon–Sat featured games (date, game key).
  final List<(String, String)> featured;
  final int rankedUsed;
  final int rankedAllowed;
  final int stars;

  bool get hasRankedEntry => rankedUsed < rankedAllowed;

  factory Today.fromJson(Map<String, dynamic> json) {
    List<ChallengeCard> cards(Object? v) => [for (final c in (v as List? ?? const [])) ChallengeCard.fromJson(_map(c))];
    final entries = _map(json['rankedEntries']);
    return Today(
      serverNowUtc: _date(json['serverNowUtc']),
      utcDate: json['utcDate'] as String,
      localDate: json['localDate'] as String,
      weekKey: json['weekKey'] as String,
      isGrandDay: json['isGrandDay'] as bool? ?? false,
      rounds: cards(json['rounds']),
      nextRound: json['nextRound'] == null ? null : ChallengeCard.fromJson(_map(json['nextRound'])),
      daily: json['daily'] == null ? null : ChallengeCard.fromJson(_map(json['daily'])),
      grand: cards(json['grand']),
      featured: [for (final f in (json['featured'] as List? ?? const [])) ((f as Map)['date'] as String, f['gameKey'] as String)],
      rankedUsed: _int(entries['used']),
      rankedAllowed: _int(entries['allowed']),
      stars: _int(json['stars']),
    );
  }
}

class BoardEntry {
  const BoardEntry({required this.rank, required this.displayName, required this.countryCode, required this.points, required this.elapsedMs, required this.isMe});

  final int rank;
  final String displayName;
  final String? countryCode;
  final double points;
  final int? elapsedMs;
  final bool isMe;

  factory BoardEntry.fromJson(Map<String, dynamic> json) => BoardEntry(
    rank: _int(json['rank']),
    displayName: json['displayName'] as String,
    countryCode: json['countryCode'] as String?,
    points: (json['points'] as num).toDouble(),
    elapsedMs: (json['elapsedMs'] as num?)?.toInt(),
    isMe: json['isMe'] as bool? ?? false,
  );
}

class Board {
  const Board({
    required this.period,
    required this.key,
    required this.scope,
    required this.scopeName,
    required this.gameKey,
    required this.isFinal,
    required this.total,
    required this.entries,
    required this.me,
  });

  final BoardPeriod period;
  final String key;
  final BoardScope scope;
  final String? scopeName;
  final String? gameKey;
  final bool isFinal;
  final int total;
  final List<BoardEntry> entries;

  /// The player's row when it is outside [entries].
  final BoardEntry? me;

  factory Board.fromJson(Map<String, dynamic> json) => Board(
    period: BoardPeriod.values[_int(json['period'])],
    key: json['key'] as String,
    scope: BoardScope.values[_int(json['scope'])],
    scopeName: json['scopeName'] as String?,
    gameKey: json['gameKey'] as String?,
    isFinal: json['final'] as bool? ?? false,
    total: _int(json['total']),
    entries: [for (final e in json['entries'] as List) BoardEntry.fromJson(_map(e))],
    me: json['me'] == null ? null : BoardEntry.fromJson(_map(json['me'])),
  );
}

class GroupInfo {
  const GroupInfo({required this.groupId, required this.name, required this.inviteCode, required this.inviteUrl, required this.memberCount, required this.isOwner});

  final String groupId;
  final String name;
  final String inviteCode;
  final String inviteUrl;
  final int memberCount;
  final bool isOwner;

  factory GroupInfo.fromJson(Map<String, dynamic> json) => GroupInfo(
    groupId: json['groupId'] as String,
    name: json['name'] as String,
    inviteCode: json['inviteCode'] as String,
    inviteUrl: json['inviteUrl'] as String,
    memberCount: _int(json['memberCount']),
    isOwner: json['isOwner'] as bool? ?? false,
  );
}

class GroupMemberInfo {
  const GroupMemberInfo({required this.displayName, required this.countryCode, required this.isOwner, required this.isMe});

  final String displayName;
  final String? countryCode;
  final bool isOwner;
  final bool isMe;

  factory GroupMemberInfo.fromJson(Map<String, dynamic> json) => GroupMemberInfo(
    displayName: json['displayName'] as String,
    countryCode: json['countryCode'] as String?,
    isOwner: json['isOwner'] as bool? ?? false,
    isMe: json['isMe'] as bool? ?? false,
  );
}

class GroupDetail {
  const GroupDetail({required this.group, required this.members});

  final GroupInfo group;
  final List<GroupMemberInfo> members;

  factory GroupDetail.fromJson(Map<String, dynamic> json) => GroupDetail(
    group: GroupInfo.fromJson(_map(json['group'])),
    members: [for (final m in json['members'] as List) GroupMemberInfo.fromJson(_map(m))],
  );
}

class GroupInvite {
  const GroupInvite({required this.name, required this.memberCount, required this.alreadyMember});

  final String name;
  final int memberCount;
  final bool alreadyMember;

  factory GroupInvite.fromJson(Map<String, dynamic> json) =>
      GroupInvite(name: json['name'] as String, memberCount: _int(json['memberCount']), alreadyMember: json['alreadyMember'] as bool? ?? false);
}
