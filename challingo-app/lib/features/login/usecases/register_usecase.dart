import '../../../core/interfaces/base_result.dart';
import '../../../core/interfaces/base_usecase.dart';
import '../domain/entities/login_response.dart';
import '../domain/repositories/login_repository.dart';

class RegisterRequest extends Request {
  final String phone;

  RegisterRequest({
    required this.phone,
  });

  @override
  Failure? validate() => null;

  @override
  Map<String, dynamic> toJson() => Request.apiEnvelope({'PhoneNumber': phone});
}

class RegisterResponse extends UseCaseResponse {
  final UserEntity? user;

  RegisterResponse({super.success, this.user, super.message, super.error});
}

class RegisterUsecase extends RepositoryVoidUseCase<RegisterResponse, RegisterRequest> {
  final LoginRepository _repository;

  RegisterUsecase(this._repository);

  @override
  Future<RegisterResponse> fetchFromRepository(RegisterRequest request) =>
      _repository.register(request);
}
