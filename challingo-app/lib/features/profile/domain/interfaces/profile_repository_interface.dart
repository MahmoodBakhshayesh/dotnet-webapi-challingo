import '../../usecases/update_profile_usecase.dart';

abstract class ProfileRepositoryInterface {
  Future<UpdateProfileResponse> updateProfile(UpdateProfileRequest request);
}