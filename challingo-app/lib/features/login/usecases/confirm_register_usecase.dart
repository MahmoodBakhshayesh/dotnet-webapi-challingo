import '../../../core/interfaces/base_result.dart';
import '../../../core/interfaces/base_usecase.dart';
import '../domain/repositories/login_repository.dart';

class ConfirmRegisterRequest extends Request {
  final String phone;
  final String code;

  ConfirmRegisterRequest({
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

class ConfirmRegisterResponse extends UseCaseResponse {
  final String? token;

  ConfirmRegisterResponse({super.success, this.token, super.message, super.error});
}

class ConfirmRegisterUsecase extends RepositoryUseCase<String, ConfirmRegisterResponse, ConfirmRegisterRequest> {
  final LoginRepository _repository;

  ConfirmRegisterUsecase(this._repository);

  @override
  Future<ConfirmRegisterResponse> fetchFromRepository(ConfirmRegisterRequest request) =>
      _repository.confirmRegister(request);

  @override
  String? dataFromResponse(ConfirmRegisterResponse response) => response.token;
}
