import 'package:get_it/get_it.dart';
import 'package:challingo/core/helpers/di_feature_stack.dart';
import 'package:challingo/features/home/domain/data_sources/home_data_source_local.dart';
import 'package:challingo/features/home/domain/data_sources/home_data_source_remote.dart';
import 'package:challingo/features/home/domain/repositories/home_repository.dart';

void registerHomeDependencies(GetIt locator) {
  registerFeatureStack<HomeDataSourceLocal, HomeDataSourceRemote, HomeRepository>(
    locator: locator,
    name: 'HomeDataSource',
    createLocal: (l) => HomeDataSourceLocal(l()),
    createRemote: (l) => HomeDataSourceRemote(l()),
    createRepository: HomeRepository.builder,
  );
}
