import 'package:get_it/get_it.dart';
import 'package:challingo/core/helpers/di_feature_stack.dart';
import 'package:challingo/features/profile/domain/data_sources/profile_data_source_local.dart';
import 'package:challingo/features/profile/domain/data_sources/profile_data_source_remote.dart';
import 'package:challingo/features/profile/domain/repositories/profile_repository.dart';
import 'package:challingo/features/profile/usecases/update_profile_usecase.dart';

void registerProfileDependencies(GetIt locator) {
  registerFeatureStack<ProfileDataSourceLocal, ProfileDataSourceRemote, ProfileRepository>(
    locator: locator,
    name: 'ProfileDataSource',
    createLocal: (l) => ProfileDataSourceLocal(l()),
    createRemote: (l) => ProfileDataSourceRemote(l()),
    createRepository: ProfileRepository.builder,
  );

  locator.registerLazySingleton(() => UpdateProfileUsecase(locator()));
}
