import '/features/login/domain/entities/login_response.dart';
import '/features/profile/usecases/update_profile_usecase.dart';

import '../../../../core/interfaces/base_data_source.dart';
import '../interfaces/profile_data_source_interface.dart';

class ProfileDataSourceLocal extends LocalDataSource implements ProfileDataSourceInterface {
  ProfileDataSourceLocal(super.keyValueStore);

  @override
  Future<UserEntity?> updateProfile(UpdateProfileRequest request) {
    // TODO: implement updateProfile
    throw UnimplementedError();
  }



}
