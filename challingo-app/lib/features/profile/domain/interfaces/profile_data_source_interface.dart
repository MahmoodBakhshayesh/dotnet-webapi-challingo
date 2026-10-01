import '/features/login/domain/entities/login_response.dart';

import '../../usecases/update_profile_usecase.dart';

abstract class ProfileDataSourceInterface {
  Future<UserEntity?> updateProfile( UpdateProfileRequest request);
}