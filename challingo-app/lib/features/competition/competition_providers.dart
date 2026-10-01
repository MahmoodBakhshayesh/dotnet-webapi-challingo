import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

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

/// Today's rounds, daily puzzle, Grand Challenge, entries and stars. Refreshes when the server announces or
/// closes something, and when the next known open/close time passes.
final todayProvider = AsyncNotifierProvider<TodayController, Today>(TodayController.new);

class TodayController extends AsyncNotifier<Today> {
  Timer? _boundary;
  Duration _offset = Duration.zero;

  /// Device clock corrected to server time.
  DateTime serverNow() => DateTime.now().toUtc().add(_offset);

  @override
  Future<Today> build() async {
    // Follow the signed-in player.
    ref.watch(sessionProvider.select((s) => s.value?.userId));
    refreshOnLive(ref, const ['round.opened', 'round.finalized', 'day.closed', 'week.closed', 'stars.awarded'], refresh);
    ref.onDispose(() => _boundary?.cancel());

    final today = await ref.read(challingoApiProvider).today();
    _offset = today.serverNowUtc.difference(DateTime.now().toUtc());
    _scheduleBoundary(today);
    return today;
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(() => ref.read(challingoApiProvider).today());
    // Keep showing the last good data when a background refresh fails.
    if (next.hasValue || !state.hasValue) state = next;
    if (next.value case final today?) {
      _offset = today.serverNowUtc.difference(DateTime.now().toUtc());
      _scheduleBoundary(today);
    }
  }

  void _scheduleBoundary(Today today) {
    _boundary?.cancel();
    final now = serverNow();
    final times = [
      for (final c in [...today.rounds, ?today.nextRound, ?today.daily, ...today.grand]) ...[c.opensAtUtc, c.closesAtUtc],
      // Midnight UTC: a new day of rounds.
      DateTime.utc(now.year, now.month, now.day + 1),
    ].where((t) => t.isAfter(now)).toList()
      ..sort();
    if (times.isEmpty) return;
    // A little after the boundary, so the server has moved on too.
    _boundary = Timer(times.first.difference(now) + const Duration(seconds: 3), refresh);
  }
}

typedef BoardRequest = ({BoardPeriod period, String? key, BoardScope scope, String? groupId});

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
  return api.board(request.period, key: request.key, scope: request.scope, groupId: request.groupId);
});

/// The player's groups.
final groupsProvider = FutureProvider<List<GroupInfo>>((ref) async {
  ref.watch(sessionProvider.select((s) => s.value?.userId));
  return ref.read(challingoApiProvider).groups();
});

final groupDetailProvider = FutureProvider.autoDispose.family<GroupDetail, String>(
  (ref, groupId) => ref.read(challingoApiProvider).group(groupId),
);
