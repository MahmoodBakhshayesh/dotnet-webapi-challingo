import 'package:challingo/core/helpers/use_case_response_mapper.dart';
import 'package:challingo/core/interfaces/base_repository.dart';
import 'package:challingo/features/profile/domain/data_sources/profile_data_source_local.dart';
import 'package:challingo/features/profile/domain/data_sources/profile_data_source_remote.dart';
import 'package:get_it/get_it.dart';

import '../../usecases/update_profile_usecase.dart';
import '../interfaces/profile_repository_interface.dart';

class ProfileRepository extends BaseRepository implements ProfileRepositoryInterface {
  final ProfileDataSourceRemote remoteDataSource;
  final ProfileDataSourceLocal localDataSource;

  ProfileRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  static ProfileRepository builder() {
    return ProfileRepository(
      remoteDataSource: GetIt.instance.get(instanceName: 'ProfileDataSourceRemote'),
      localDataSource: GetIt.instance.get(instanceName: 'ProfileDataSourceLocal'),
    );
  }

  @override
  Future<UpdateProfileResponse> updateProfile(UpdateProfileRequest request) {
    return mapUseCaseResponse(
      () => remoteDataSource.updateProfile(request),
      onSuccess: (profileData) => UpdateProfileResponse(profileData: profileData),
      create: UpdateProfileResponse.new,
    );
  }
}
