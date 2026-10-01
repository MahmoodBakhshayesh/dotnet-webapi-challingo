import 'dart:io';

/// Ad and store keys, set per build with --dart-define. Defaults are Google's public test ad units, which never
/// reach our server's verification callback; in that case the app asks the API for a test reward instead
/// (only allowed when the API runs with Monetization__AllowDevRewards=true).
class MonetizationConfig {
  MonetizationConfig._();

  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';

  static const _rewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS', defaultValue: _testRewardedIos);
  static const _rewardedAndroid = String.fromEnvironment('ADMOB_REWARDED_ANDROID', defaultValue: _testRewardedAndroid);

  static String get rewardedAdUnit => Platform.isIOS ? _rewardedIos : _rewardedAndroid;

  /// True with Google's test units: rewards then come from the API's test endpoint.
  static bool get usingTestAds => rewardedAdUnit == _testRewardedIos || rewardedAdUnit == _testRewardedAndroid;

  /// RevenueCat public SDK keys (appl_… / goog_…). Empty = store not set up yet.
  static const _revenueCatApple = String.fromEnvironment('RC_APPLE_KEY');
  static const _revenueCatGoogle = String.fromEnvironment('RC_GOOGLE_KEY');

  static String get revenueCatKey => Platform.isIOS ? _revenueCatApple : _revenueCatGoogle;

  static bool get storeConfigured => revenueCatKey.isNotEmpty;

  /// The RevenueCat entitlement that means Plus.
  static const plusEntitlement = 'plus';
}
