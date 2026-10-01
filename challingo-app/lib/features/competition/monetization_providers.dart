import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/competition_models.dart';
import '../../core/monetization/ads_service.dart';
import '../../core/monetization/monetization_config.dart';
import '../../core/monetization/purchases_service.dart';
import '../../core/session/session_controller.dart';
import 'competition_providers.dart';

/// Plus and today's rewarded ads. Refreshes when the server confirms an ad or a subscription change.
final monetizationProvider = AsyncNotifierProvider<MonetizationController, MonetizationStatus>(MonetizationController.new);

class MonetizationController extends AsyncNotifier<MonetizationStatus> {
  @override
  Future<MonetizationStatus> build() async {
    ref.watch(sessionProvider.select((s) => s.value?.userId));
    refreshOnLive(ref, const ['ad.rewarded', 'plus.changed'], refresh);
    final status = await ref.read(challingoApiProvider).monetizationStatus();
    unawaited(PurchasesService.instance.identify(status.rewardUserId).catchError((_) {}));
    return status;
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(() => ref.read(challingoApiProvider).monetizationStatus());
    if (next.hasValue || !state.hasValue) state = next;
    await ref.read(lobbyProvider.notifier).refresh();
  }

  /// Shows a rewarded ad. Returns true once the server has counted it (+run, +stars).
  Future<bool> watchAd() async {
    final api = ref.read(challingoApiProvider);
    final before = state.value ?? await api.monetizationStatus();
    if (before.adsLeft == 0 || before.plusActive) return false;

    final earned = await AdsService.instance.showRewarded(userId: before.rewardUserId);
    if (!earned) return false;

    MonetizationStatus? after;
    if (MonetizationConfig.usingTestAds && before.devRewards) {
      // Google's test ads never call our verification URL: ask the API for a test reward instead.
      after = await api.devAdReward();
    } else {
      // The reward arrives through AdMob's signed callback to our API; wait for it.
      for (var i = 0; i < 15 && (after == null || after.adsToday <= before.adsToday); i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        after = await api.monetizationStatus();
      }
    }
    state = AsyncData(after ?? before);
    await ref.read(lobbyProvider.notifier).refresh();
    return after != null && after.adsToday > before.adsToday;
  }

  /// After a purchase or restore: ask the API to re-read RevenueCat.
  Future<void> syncPlus() async {
    state = AsyncData(await ref.read(challingoApiProvider).syncPlus());
    await ref.read(lobbyProvider.notifier).refresh();
  }

  /// Development only.
  Future<void> devPlus(int days) async {
    state = AsyncData(await ref.read(challingoApiProvider).devPlus(days));
    await ref.read(lobbyProvider.notifier).refresh();
  }
}
