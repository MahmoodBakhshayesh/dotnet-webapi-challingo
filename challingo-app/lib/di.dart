import 'package:fast_cached_network_image/fast_cached_network_image.dart';
import 'package:get_it/get_it.dart';
import 'core/constants/keys.dart';
import 'core/data/app_data.dart';
import 'core/database/sembast.dart';
import 'core/di/app_features_di.dart';
import 'core/helpers/api_service.dart';
import 'core/helpers/app_overlays_helper.dart';
import 'core/helpers/go_router_helper.dart';
import 'core/helpers/logger_service.dart';
import 'core/helpers/shared_preferences_helper.dart';
import 'core/interfaces/base_config.dart';
import 'core/interfaces/base_key_value_store.dart';
import 'core/interfaces/base_navigation_service.dart';
import 'core/interfaces/base_overlays_helper.dart';
import 'core/models/base/flavor_config.dart';
import 'core/services/config_service.dart';

GetIt locator = GetIt.instance;

final sessionStorage = locator<BaseKeyValueStore>(instanceName: Keys.sessionStorageInstance);

LoggerService registerLoggerService() {
  return locator.registerSingleton(LoggerService());
}

Future<void> initializeStorages() async {
  return registerStorage(locator);
}

Future<void> initSembast() async {
  final sembastDb = await SemBastDB.init();
  locator.registerSingleton<SemBastDB>(sembastDb);
}

Future<void> initPackages() async {
  await FastCachedImageConfig.init();
}

/// Determine the flavor and initialize the config. This must be the first
/// step to ensure that all subsequent parts of the app can access it.
Future<void> initializeAppConfig({String? baseUrl}) async {
  final configService = ConfigService.instance;
  if (baseUrl != null) {
    final currentConfig = await configService.loadConfig();
    final userConfig = currentConfig.copyWith(baseUrl: baseUrl);
    await configService.saveUserConfig(userConfig);
  }

  appConfig = await configService.loadConfig();
}

void initializeDependencies() {
  /// Core Services
  locator.registerSingleton<BaseNavigationService>(GoRouterHelper());
  locator.registerLazySingleton<BaseOverlaysHelper>(() => AppOverlaysHelper());
  locator.registerLazySingleton<ApiService>(() => ApiService.appDefault());

  registerAppFeatureDependencies(locator);
}

Future<void> registerGlobalRepositories() async {
  /// Config Repository
  final storage = locator<BaseKeyValueStore>();
  locator.registerLazySingleton<ConfigRepository>(
    () => ConfigRepository(
      AssetConfigLoader(),
      StorageConfigLoader(storage),
      DefaultConfigLoader(),
    ),
  );
  await AppData.instance.init();
}
