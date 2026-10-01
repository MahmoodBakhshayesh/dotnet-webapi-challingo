import 'package:challingo/core/helpers/use_case_response_mapper.dart';
import 'package:challingo/core/interfaces/base_repository.dart';
import 'package:challingo/features/login/usecases/check_phone_usecase.dart';
import 'package:challingo/features/login/usecases/complete_profile_usecase.dart';
import 'package:challingo/features/login/usecases/confirm_otp_login_usecase.dart';
import 'package:challingo/features/login/usecases/confirm_register_usecase.dart';
import 'package:challingo/features/login/usecases/otp_login_usecase.dart';
import 'package:challingo/features/login/usecases/register_usecase.dart';
import 'package:get_it/get_it.dart';

import '../../usecases/login_usecase.dart';
import '../data_sources/login_data_source_local.dart';
import '../data_sources/login_data_source_remote.dart';
import '../entities/login_response.dart';
import '../entities/offline_test_login.dart';
import '../interfaces/login_data_source_interface.dart';
import '../interfaces/login_repository_interface.dart';

class LoginRepository extends BaseRepository implements LoginRepositoryInterface {
  final LoginDataSourceRemote remoteDataSource;
  final LoginDataSourceLocal localDataSource;

  LoginRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  static LoginRepository builder() {
    return LoginRepository(
      remoteDataSource: GetIt.instance.get(instanceName: 'LoginDataSourceRemote'),
      localDataSource: GetIt.instance.get(instanceName: 'LoginDataSourceLocal'),
    );
  }

  @override
  Future<LoginResponse> login(LoginRequest request) {
    final LoginDataSourceInterface dataSource =
        OfflineTestLogin.matches(request.phone, request.password)
            ? localDataSource
            : remoteDataSource;
    return mapUseCaseResponse(
      () => dataSource.login(request),
      onSuccess: (loginData) => LoginResponse(loginData: loginData),
      create: LoginResponse.new,
    );
  }

  @override
  Future<UserEntity?> getUserByUsername(String username) {
    return remoteDataSource.getUserByUsername(username);
  }

  @override
  UserEntity? loadLoginResponse() {
    return null;
  }

  @override
  Future<CheckPhoneResponse> checkPhone(CheckPhoneRequest request) {
    return mapUseCaseResponse(
      () => remoteDataSource.checkPhone(request),
      onSuccess: (data) => CheckPhoneResponse(checkPhoneResponseData: data),
      create: CheckPhoneResponse.new,
    );
  }

  @override
  Future<RegisterResponse> register(RegisterRequest request) {
    return mapUseCaseResponseVoid(
      () => remoteDataSource.register(request),
      onSuccess: () => RegisterResponse(),
      create: RegisterResponse.new,
    );
  }

  @override
  Future<ConfirmRegisterResponse> confirmRegister(ConfirmRegisterRequest request) {
    return mapUseCaseResponse(
      () => remoteDataSource.confirmRegister(request),
      onSuccess: (token) => ConfirmRegisterResponse(token: token),
      create: ConfirmRegisterResponse.new,
    );
  }

  @override
  Future<CompleteProfileResponse> completeProfile(CompleteProfileRequest request) {
    return mapUseCaseResponseVoid(
      () => remoteDataSource.completeProfile(request),
      onSuccess: () => CompleteProfileResponse(),
      create: CompleteProfileResponse.new,
    );
  }

  @override
  Future<OtpLoginResponse> otpLogin(OtpLoginRequest request) {
    return mapUseCaseResponseVoid(
      () => remoteDataSource.otpLogin(request),
      onSuccess: () => const OtpLoginResponse(),
      create: OtpLoginResponse.new,
    );
  }

  @override
  Future<ConfirmOtpLoginResponse> confirmOtpLogin(ConfirmOtpLoginRequest request) {
    return mapUseCaseResponse(
      () => remoteDataSource.confirmOtpLogin(request),
      onSuccess: (loginData) => ConfirmOtpLoginResponse(loginData: loginData),
      create: ConfirmOtpLoginResponse.new,
    );
  }
}
