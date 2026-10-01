import '../../../core/interfaces/base_result.dart';
import '../../../core/interfaces/base_usecase.dart';
import '../domain/entities/check_phone_response_entity.dart';
import '../domain/repositories/login_repository.dart';

class CheckPhoneRequest extends Request {
  final String phone;

  CheckPhoneRequest({required this.phone});

  @override
  Failure? validate() => null;
  
  @override
  Map<String, dynamic> toJson() => Request.apiEnvelope({'PhoneNumber': phone});
}

class CheckPhoneResponse extends UseCaseResponse {
  final CheckPhoneResponseData? checkPhoneResponseData;

  CheckPhoneResponse({super.success, this.checkPhoneResponseData, super.message, super.error});
}

class CheckPhoneUsecase extends RepositoryUseCase<CheckPhoneResponseData, CheckPhoneResponse, CheckPhoneRequest> {
  final LoginRepository _repository;

  CheckPhoneUsecase(this._repository);

  @override
  Future<CheckPhoneResponse> fetchFromRepository(CheckPhoneRequest request) =>
      _repository.checkPhone(request);

  @override
  CheckPhoneResponseData? dataFromResponse(CheckPhoneResponse response) => response.checkPhoneResponseData;
}
