import '../../../core/interfaces/base_result.dart';
import '../../../core/interfaces/base_usecase.dart';
import '../domain/repositories/login_repository.dart';

class OtpLoginRequest extends Request {
  final String phone;

  OtpLoginRequest({required this.phone});

  @override
  Failure? validate() => null;
  
  @override
  Map<String, dynamic> toJson() => Request.apiEnvelope({'PhoneNumber': phone});
}

class OtpLoginResponse extends UseCaseResponse {
  const OtpLoginResponse({super.success, super.message, super.error});
}

class OtpLoginUsecase extends RepositoryVoidUseCase<OtpLoginResponse, OtpLoginRequest> {
  final LoginRepository _repository;

  OtpLoginUsecase(this._repository);

  @override
  Future<OtpLoginResponse> fetchFromRepository(OtpLoginRequest request) =>
      _repository.otpLogin(request);
}
