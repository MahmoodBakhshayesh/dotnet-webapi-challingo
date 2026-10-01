import 'package:get_it/get_it.dart';

import '../interfaces/base_data_source.dart';

/// Registers local + remote data sources and repository for a feature stack.
void registerFeatureStack<L extends LocalDataSource, R extends RemoteDataSource, Repo extends Object>({
  required GetIt locator,
  required String name,
  required L Function(GetIt locator) createLocal,
  required R Function(GetIt locator) createRemote,
  required Repo Function() createRepository,
}) {
  locator.registerLazySingleton<L>(
    () => createLocal(locator),
    instanceName: '${name}Local',
  );
  locator.registerLazySingleton<R>(
    () => createRemote(locator),
    instanceName: '${name}Remote',
  );
  locator.registerLazySingleton<Repo>(createRepository);
}
