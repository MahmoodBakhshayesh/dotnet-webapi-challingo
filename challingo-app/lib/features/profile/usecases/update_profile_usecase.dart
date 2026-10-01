import 'package:challingo/features/login/domain/entities/login_response.dart';

import '../../../core/interfaces/base_usecase.dart';
import '../../../core/interfaces/base_result.dart';
import '../domain/repositories/profile_repository.dart';

class UpdateProfileRequest extends Request {
  final String fullName;
  final String? username;
  final String? email;

  UpdateProfileRequest({
    required this.fullName,
    this.username,
    this.email,
  });

  @override
  Failure? validate() => null;

  @override
  Map<String, dynamic> toJson() => Request.apiEnvelope({
    'FullName': fullName,
    if (username != null && username!.isNotEmpty) 'Username': username,
    if (email != null && email!.isNotEmpty) 'Email': email,
  });
}

class UpdateProfileResponse extends UseCaseResponse {
  final UserEntity? profileData;

  UpdateProfileResponse({super.success, this.profileData, super.message, super.error});
}

class UpdateProfileUsecase extends RepositoryUseCase<UserEntity, UpdateProfileResponse, UpdateProfileRequest> {
  final ProfileRepository _repository;

  UpdateProfileUsecase(this._repository);

  @override
  Future<UpdateProfileResponse> fetchFromRepository(UpdateProfileRequest request) =>
      _repository.updateProfile(request);

  @override
  UserEntity? dataFromResponse(UpdateProfileResponse response) => response.profileData;
}
