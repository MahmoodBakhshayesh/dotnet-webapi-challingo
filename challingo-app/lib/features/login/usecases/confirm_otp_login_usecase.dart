import '../../../core/interfaces/base_result.dart';
import '../../../core/interfaces/base_usecase.dart';
import '../domain/entities/login_response.dart';
import '../domain/repositories/login_repository.dart';

class ConfirmOtpLoginRequest extends Request {
  final String phone;
  final String code;

  ConfirmOtpLoginRequest({
    required this.phone,
    required this.code,
  });

  @override
  Failure? validate() => null;

  @override
  Map<String, dynamic> toJson() => Request.apiEnvelope({
    'PhoneNumber': phone,
    'Code': code,
  });
}

class ConfirmOtpLoginResponse extends UseCaseResponse {
  final LoginResponseData? loginData;

  ConfirmOtpLoginResponse({super.success, this.loginData, super.message, super.error});
}

class ConfirmOtpLoginUsecase extends RepositoryUseCase<LoginResponseData, ConfirmOtpLoginResponse, ConfirmOtpLoginRequest> {
  final LoginRepository _repository;

  ConfirmOtpLoginUsecase(this._repository);

  @override
  Future<ConfirmOtpLoginResponse> fetchFromRepository(ConfirmOtpLoginRequest request) =>
      _repository.confirmOtpLogin(request);

  @override
  LoginResponseData? dataFromResponse(ConfirmOtpLoginResponse response) => response.loginData;
}
