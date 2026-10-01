import 'package:challingo/features/profile/usecases/update_profile_usecase.dart';

import '../../../../core/interfaces/base_data_source.dart';
import '../../../login/domain/entities/login_response.dart';
import '../interfaces/profile_data_source_interface.dart';

class ProfileDataSourceRemote extends RemoteDataSource implements ProfileDataSourceInterface {
  ProfileDataSourceRemote(super.apiService);

  @override
  Future<UserEntity?> updateProfile(UpdateProfileRequest request) async {
    final nr = await apiService.patch('users/me/profile', body: request.toJson());
    return parseBodyObjectOrNull(nr, UserEntity.fromJson);
  }
}
