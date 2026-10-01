import 'dart:async';
import 'dart:developer';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'monetization_config.dart';

/// Rewarded ads. The reward itself is granted by our server when AdMob calls its verification URL; the player id
/// passed here is how that callback knows who watched.
class AdsService {
  AdsService._();

  static final instance = AdsService._();

  Future<void>? _ready;

  /// Consent (GDPR / US privacy forms via Google's UMP) first, then the SDK. Safe to call many times.
  Future<void> ensureReady() => _ready ??= _init();

  Future<void> _init() async {
    final consent = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) log('Consent form: ${error.message}', name: 'Ads');
        consent.complete();
      }),
      (error) {
        log('Consent info: ${error.message}', name: 'Ads');
        consent.complete();
      },
    );
    await consent.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    final status = await MobileAds.instance.initialize();
    log('Ready: ${status.adapterStatuses.length} adapters', name: 'Ads');
  }

  /// Loads and shows a rewarded ad. Returns true when the player earned the reward.
  Future<bool> showRewarded({required String userId}) async {
    await ensureReady();
    if (!await ConsentInformation.instance.canRequestAds()) {
      throw const AdUnavailable('Ads need your consent choice first.');
    }

    final loaded = Completer<RewardedAd>();
    await RewardedAd.load(
      adUnitId: MonetizationConfig.rewardedAdUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          // Server-side verification: AdMob sends this user id to our API with the signed reward.
          ad.setServerSideOptions(ServerSideVerificationOptions(userId: userId, customData: 'run'));
          loaded.complete(ad);
        },
        onAdFailedToLoad: (error) {
          log('Load failed: ${error.code} ${error.message}', name: 'Ads');
          loaded.completeError(AdUnavailable(error.message));
        },
      ),
    );
    final ad = await loaded.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw const AdUnavailable('No ad available right now. Try again in a minute.'),
    );

    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!done.isCompleted) done.completeError(AdUnavailable(error.message));
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }
}

class AdUnavailable implements Exception {
  const AdUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
