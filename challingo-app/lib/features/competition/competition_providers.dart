import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/challingo_api.dart';
import '../../core/api/competition_models.dart';
import '../../core/services/realtime_service.dart';
import '../../core/session/session_controller.dart';

/// Re-runs [refresh] whenever one of the server's push [methods] arrives.
void refreshOnLive(Ref ref, List<String> methods, void Function() refresh) {
  final offs = [for (final m in methods) RealtimeService.instance.on(m, (_) => refresh())];
  ref.onDispose(() {
    for (final off in offs) {
      off();
    }
  });
}

/// SignalR topic of a challenge's live board (server: `challenge:{id:N}`).
String challengeTopic(String challengeId) => 'challenge:${challengeId.replaceAll('-', '').toLowerCase()}';

/// SignalR topic of the live Grand board (server: `grand:{week}` lowercase).
String grandTopic(String weekKey) => 'grand:${weekKey.toLowerCase()}';

/// Every game's current and next run, the Grand Challenge, entries and stars. Refreshes when the server
/// opens or closes something, and when the next known open / join-close time passes.
final lobbyProvider = AsyncNotifierProvider<LobbyController, Lobby>(LobbyController.new);

class LobbyController extends AsyncNotifier<Lobby> {
  Timer? _boundary;
  Duration _offset = Duration.zero;

  /// Device clock corrected to server time.
  DateTime serverNow() => DateTime.now().toUtc().add(_offset);

  @override
  Future<Lobby> build() async {
    // Follow the signed-in player.
    ref.watch(sessionProvider.select((s) => s.value?.userId));
    refreshOnLive(ref, const ['run.opened', 'round.finalized', 'board.closed', 'stars.awarded', 'lottery.settled'], refresh);
    ref.onDispose(() => _boundary?.cancel());

    final lobby = await ref.read(challingoApiProvider).lobby();
    _offset = lobby.serverNowUtc.difference(DateTime.now().toUtc());
    _scheduleBoundary(lobby);
    return lobby;
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(() => ref.read(challingoApiProvider).lobby());
    // Keep showing the last good data when a background refresh fails.
    if (next.hasValue || !state.hasValue) state = next;
    if (next.value case final lobby?) {
      _offset = lobby.serverNowUtc.difference(DateTime.now().toUtc());
      _scheduleBoundary(lobby);
    }
  }

  void _scheduleBoundary(Lobby lobby) {
    _boundary?.cancel();
    final now = serverNow();
    final times = [
      for (final g in lobby.games) ...[?g.current?.joinClosesAtUtc, ?g.next?.opensAtUtc],
      for (final c in lobby.grand) ...[c.opensAtUtc, c.joinClosesAtUtc],
    ].where((t) => t.isAfter(now)).toList()
      ..sort();
    if (times.isEmpty) return;
    // A little after the boundary, so the server has moved on too.
    _boundary = Timer(times.first.difference(now) + const Duration(seconds: 2), refresh);
  }
}

/// Today's lottery draw; refreshes on every revealed digit and when it settles.
final lotteryProvider = AsyncNotifierProvider<LotteryController, Lottery?>(LotteryController.new);

class LotteryController extends AsyncNotifier<Lottery?> {
  Timer? _boundary;

  @override
  Future<Lottery?> build() async {
    ref.watch(sessionProvider.select((s) => s.value?.userId));
    refreshOnLive(ref, const ['lottery.digit', 'lottery.settled'], refresh);
    ref.onDispose(() => _boundary?.cancel());
    return _load();
  }

  Future<Lottery?> _load() async {
    Lottery? lottery;
    try {
      lottery = await ref.read(challingoApiProvider).lotteryToday();
    } on ApiFailure catch (f) {
      if (f.statusCode != 404) rethrow;
    }
    _schedule(lottery);
    return lottery;
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(_load);
    if (next.hasValue || !state.hasValue) state = next;
  }

  /// Picks (or changes) today's number; null = lucky dip.
  Future<void> pick(String? number) async {
    final updated = await ref.read(challingoApiProvider).pickLottery(number);
    state = AsyncData(updated);
  }

  // Refresh at the next digit, at picks close, and at midnight UTC (a new draw).
  void _schedule(Lottery? lottery) {
    _boundary?.cancel();
    final now = ref.read(lobbyProvider.notifier).serverNow();
    final times = [
      ?lottery?.nextRevealAtUtc,
      ?lottery?.picksCloseAtUtc,
      DateTime.utc(now.year, now.month, now.day + 1),
    ].where((t) => t.isAfter(now)).toList()
      ..sort();
    if (times.isEmpty) return;
    _boundary = Timer(times.first.difference(now) + const Duration(seconds: 2), refresh);
  }
}

final lotteryHistoryProvider = FutureProvider.autoDispose<List<Lottery>>((ref) => ref.read(challingoApiProvider).lotteryHistory());

typedef BoardRequest = ({BoardPeriod period, String? gameKey, String? key, BoardScope scope, String? groupId});

/// One board; round and Grand boards refresh live while they are on screen.
final boardProvider = FutureProvider.autoDispose.family<Board, BoardRequest>((ref, request) async {
  final api = ref.read(challingoApiProvider);
  String? topic;
  if (request.period == BoardPeriod.round && request.key != null) topic = challengeTopic(request.key!);
  if (request.period == BoardPeriod.grand && request.key != null) topic = grandTopic(request.key!);
  if (topic != null) {
    final t = topic;
    unawaited(RealtimeService.instance.subscribe(t).catchError((_) {}));
    Timer? debounce;
    refreshOnLive(ref, const ['board.changed', 'round.finalized'], () {
      // Many players can finish at once: refresh at most every two seconds.
      debounce ??= Timer(const Duration(seconds: 2), () {
        debounce = null;
        ref.invalidateSelf();
      });
    });
    ref.onDispose(() {
      debounce?.cancel();
      unawaited(RealtimeService.instance.unsubscribe(t).catchError((_) {}));
    });
  }
  return api.board(request.period, gameKey: request.gameKey, key: request.key, scope: request.scope, groupId: request.groupId);
});

/// The player's groups.
final groupsProvider = FutureProvider<List<GroupInfo>>((ref) async {
  ref.watch(sessionProvider.select((s) => s.value?.userId));
  return ref.read(challingoApiProvider).groups();
});

final groupDetailProvider = FutureProvider.autoDispose.family<GroupDetail, String>(
  (ref, groupId) => ref.read(challingoApiProvider).group(groupId),
);
