import '../../../core/interfaces/base_result.dart';
import '../../../core/interfaces/base_usecase.dart';
import '../domain/entities/login_response.dart';
import '../domain/repositories/login_repository.dart';

class LoginRequest extends Request {
  final String phone;
  final String password;

  LoginRequest({required this.phone, required this.password});

  @override
  Failure? validate() => null;
  
  @override
  Map<String, dynamic> toJson() => Request.plainJson({
        'username': phone,
        'password': password,
      });
}

class LoginResponse extends UseCaseResponse {
  final LoginResponseData? loginData;

  LoginResponse({super.success, this.loginData, super.message, super.error});
}

class LoginUsecase extends RepositoryUseCase<LoginResponseData, LoginResponse, LoginRequest> {
  final LoginRepository _repository;

  LoginUsecase(this._repository);

  @override
  Future<LoginResponse> fetchFromRepository(LoginRequest request) => _repository.login(request);

  @override
  LoginResponseData? dataFromResponse(LoginResponse response) => response.loginData;
}
