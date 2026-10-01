import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'monetization_config.dart';

/// Plus through RevenueCat. The app user id is our player id, so RevenueCat's webhooks name the right player.
class PurchasesService {
  PurchasesService._();

  static final instance = PurchasesService._();

  bool _configured = false;
  String? _userId;

  bool get available => MonetizationConfig.storeConfigured;

  Future<void> identify(String userId) async {
    if (!available) return;
    if (!_configured) {
      await Purchases.configure(PurchasesConfiguration(MonetizationConfig.revenueCatKey)..appUserID = userId);
      _configured = true;
      _userId = userId;
    } else if (_userId != userId) {
      await Purchases.logIn(userId);
      _userId = userId;
    }
  }

  /// The current offering's packages (monthly, annual…), or empty when the store is not set up.
  Future<List<Package>> packages(String userId) async {
    if (!available) return const [];
    await identify(userId);
    final offerings = await Purchases.getOfferings();
    return offerings.current?.availablePackages ?? const [];
  }

  /// Buys a package. Returns false when the player cancelled.
  Future<bool> buy(String userId, Package package) async {
    await identify(userId);
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      return true;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  Future<void> restore(String userId) async {
    await identify(userId);
    await Purchases.restorePurchases();
  }
}
