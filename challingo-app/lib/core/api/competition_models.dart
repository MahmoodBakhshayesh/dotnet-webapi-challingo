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

/// Matches the API's BoardPeriod (ints: append only).
enum BoardPeriod { round, day, week, grand, allTime, month }

/// Matches the API's LotteryPhase.
enum LotteryPhase { picking, revealing, settled }

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
  const MyAttempt({required this.status, required this.elapsedMs, required this.points, required this.rank});

  final AttemptStatus status;
  final int? elapsedMs;
  final int? points;
  final int? rank;

  bool get finished => status != AttemptStatus.inProgress;

  factory MyAttempt.fromJson(Map<String, dynamic> json) => MyAttempt(
    status: AttemptStatus.values[_int(json['status'])],
    elapsedMs: (json['elapsedMs'] as num?)?.toInt(),
    points: (json['points'] as num?)?.toInt(),
    rank: (json['rank'] as num?)?.toInt(),
  );
}

/// One ranked run or Grand game.
class RunCard {
  const RunCard({
    required this.challengeId,
    required this.kind,
    required this.gameKey,
    required this.sequence,
    this.difficulty = 0,
    required this.opensAtUtc,
    required this.joinClosesAtUtc,
    required this.closesAtUtc,
    required this.finalized,
    required this.my,
  });

  final String challengeId;
  final ChallengeKind kind;
  final String gameKey;
  final int sequence;

  /// 1 = Beginner … 4 = Expert.
  final int difficulty;
  final DateTime opensAtUtc;

  /// Last moment to start.
  final DateTime joinClosesAtUtc;

  /// Started attempts may finish until this.
  final DateTime closesAtUtc;
  final bool finalized;
  final MyAttempt? my;

  /// Judged against server time (the state from the API ages).
  ChallengeState stateAt(DateTime serverNow) => serverNow.isBefore(opensAtUtc)
      ? ChallengeState.upcoming
      : serverNow.isBefore(joinClosesAtUtc)
      ? ChallengeState.open
      : ChallengeState.closed;

  factory RunCard.fromJson(Map<String, dynamic> json) => RunCard(
    challengeId: json['challengeId'] as String,
    kind: ChallengeKind.values[_int(json['kind'])],
    gameKey: json['gameKey'] as String,
    sequence: _int(json['sequence']),
    difficulty: (json['difficulty'] as num?)?.toInt() ?? 0,
    opensAtUtc: _date(json['opensAtUtc']),
    joinClosesAtUtc: _date(json['joinClosesAtUtc']),
    closesAtUtc: _date(json['closesAtUtc']),
    finalized: json['finalized'] as bool? ?? false,
    my: json['my'] == null ? null : MyAttempt.fromJson(_map(json['my'])),
  );
}

/// A game in the lobby.
class GameLobby {
  const GameLobby({
    required this.gameKey,
    required this.everyMinutes,
    required this.current,
    required this.next,
    required this.dayPoints,
    required this.dayRank,
    required this.runsToday,
  });

  final String gameKey;
  final int everyMinutes;

  /// The run you can join now.
  final RunCard? current;
  final RunCard? next;

  /// Your points on this game's day board (closed runs) and rank there.
  final double? dayPoints;
  final int? dayRank;
  final int runsToday;

  factory GameLobby.fromJson(Map<String, dynamic> json) => GameLobby(
    gameKey: json['gameKey'] as String,
    everyMinutes: _int(json['everyMinutes']),
    current: json['current'] == null ? null : RunCard.fromJson(_map(json['current'])),
    next: json['next'] == null ? null : RunCard.fromJson(_map(json['next'])),
    dayPoints: (json['dayPoints'] as num?)?.toDouble(),
    dayRank: (json['dayRank'] as num?)?.toInt(),
    runsToday: _int(json['runsToday'] ?? 0),
  );
}

class Lobby {
  const Lobby({
    required this.serverNowUtc,
    required this.utcDate,
    required this.weekKey,
    required this.monthKey,
    required this.games,
    required this.grand,
    required this.isGrandDay,
    required this.rankedUsed,
    required this.rankedAllowed,
    required this.adsToday,
    required this.adsPerDay,
    required this.plus,
    required this.stars,
    required this.lottery,
  });

  final DateTime serverNowUtc;
  final String utcDate;
  final String weekKey;
  final String monthKey;
  final List<GameLobby> games;

  /// This week's Grand Challenge (Sunday).
  final List<RunCard> grand;
  final bool isGrandDay;
  final int rankedUsed;

  /// Null = unlimited (Plus).
  final int? rankedAllowed;

  /// Rewarded ads counted today (each adds a run and stars) and the daily maximum.
  final int adsToday;
  final int adsPerDay;
  final bool plus;
  final int stars;
  final Lottery? lottery;

  bool get hasRankedEntry => rankedAllowed == null || rankedUsed < rankedAllowed!;

  bool get canWatchAd => !plus && adsToday < adsPerDay;

  GameLobby? game(String key) => games.where((g) => g.gameKey == key).firstOrNull;

  factory Lobby.fromJson(Map<String, dynamic> json) {
    final entries = _map(json['rankedEntries']);
    return Lobby(
      serverNowUtc: _date(json['serverNowUtc']),
      utcDate: json['utcDate'] as String,
      weekKey: json['weekKey'] as String,
      monthKey: json['monthKey'] as String,
      games: [for (final g in json['games'] as List) GameLobby.fromJson(_map(g))],
      grand: [for (final g in (json['grand'] as List? ?? const [])) RunCard.fromJson(_map(g))],
      isGrandDay: json['isGrandDay'] as bool? ?? false,
      rankedUsed: _int(entries['used']),
      rankedAllowed: (entries['allowed'] as num?)?.toInt(),
      adsToday: _int(entries['adsToday'] ?? 0),
      adsPerDay: _int(entries['adsPerDay'] ?? 0),
      plus: entries['plus'] as bool? ?? false,
      stars: _int(json['stars']),
      lottery: json['lottery'] == null ? null : Lottery.fromJson(_map(json['lottery'])),
    );
  }
}

class LotteryTicket {
  const LotteryTicket({required this.number, required this.match, required this.alive});

  final String number;

  /// Digits matched so far, from the first.
  final int match;

  /// Still matching every revealed digit.
  final bool alive;

  factory LotteryTicket.fromJson(Map<String, dynamic> json) =>
      LotteryTicket(number: json['number'] as String, match: _int(json['match']), alive: json['alive'] as bool? ?? false);
}

class LotteryResult {
  const LotteryResult({
    required this.number,
    required this.salt,
    required this.winningMatch,
    required this.winners,
    required this.prizePerWinner,
    required this.rolledOver,
    required this.myPrize,
  });

  final String number;
  final String salt;
  final int winningMatch;
  final int winners;
  final int prizePerWinner;
  final bool rolledOver;
  final int myPrize;

  factory LotteryResult.fromJson(Map<String, dynamic> json) => LotteryResult(
    number: json['number'] as String,
    salt: json['salt'] as String,
    winningMatch: _int(json['winningMatch']),
    winners: _int(json['winners']),
    prizePerWinner: _int(json['prizePerWinner']),
    rolledOver: json['rolledOver'] as bool? ?? false,
    myPrize: _int(json['myPrize']),
  );
}

class Lottery {
  const Lottery({
    required this.dayKey,
    required this.phase,
    required this.picksCloseAtUtc,
    required this.nextRevealAtUtc,
    required this.endsAtUtc,
    required this.revealed,
    required this.commitHash,
    required this.pot,
    required this.players,
    required this.alive,
    required this.my,
    required this.result,
  });

  static const digits = 10;

  final String dayKey;
  final LotteryPhase phase;
  final DateTime picksCloseAtUtc;
  final DateTime? nextRevealAtUtc;
  final DateTime endsAtUtc;

  /// Digits revealed so far, in order.
  final String revealed;
  final String commitHash;
  final int pot;
  final int players;
  final int alive;
  final LotteryTicket? my;
  final LotteryResult? result;

  factory Lottery.fromJson(Map<String, dynamic> json) => Lottery(
    dayKey: json['dayKey'] as String,
    phase: LotteryPhase.values[_int(json['phase'])],
    picksCloseAtUtc: _date(json['picksCloseAtUtc']),
    nextRevealAtUtc: json['nextRevealAtUtc'] == null ? null : _date(json['nextRevealAtUtc']),
    endsAtUtc: _date(json['endsAtUtc']),
    revealed: json['revealed'] as String? ?? '',
    commitHash: json['commitHash'] as String,
    pot: _int(json['pot']),
    players: _int(json['players']),
    alive: _int(json['alive']),
    my: json['my'] == null ? null : LotteryTicket.fromJson(_map(json['my'])),
    result: json['result'] == null ? null : LotteryResult.fromJson(_map(json['result'])),
  );
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

class MonetizationStatus {
  const MonetizationStatus({
    required this.plusActive,
    required this.plusExpiresAtUtc,
    required this.plusStore,
    required this.adsToday,
    required this.adsPerDay,
    required this.runsPerAd,
    required this.starsPerAd,
    required this.rewardUserId,
    required this.devRewards,
  });

  final bool plusActive;
  final DateTime? plusExpiresAtUtc;
  final String? plusStore;
  final int adsToday;
  final int adsPerDay;
  final int runsPerAd;
  final int starsPerAd;

  /// Passed to AdMob (server-side verification) and RevenueCat.
  final String rewardUserId;

  /// The API allows test grants (development).
  final bool devRewards;

  int get adsLeft => (adsPerDay - adsToday).clamp(0, adsPerDay);

  factory MonetizationStatus.fromJson(Map<String, dynamic> json) {
    final plus = _map(json['plus']);
    return MonetizationStatus(
      plusActive: plus['active'] as bool? ?? false,
      plusExpiresAtUtc: plus['expiresAtUtc'] == null ? null : _date(plus['expiresAtUtc']),
      plusStore: plus['store'] as String?,
      adsToday: _int(json['adsToday']),
      adsPerDay: _int(json['adsPerDay']),
      runsPerAd: _int(json['runsPerAd']),
      starsPerAd: _int(json['starsPerAd']),
      rewardUserId: json['rewardUserId'] as String,
      devRewards: json['devRewards'] as bool? ?? false,
    );
  }
}
