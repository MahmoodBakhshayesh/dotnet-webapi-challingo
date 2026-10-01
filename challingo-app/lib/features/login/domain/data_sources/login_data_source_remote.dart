import 'package:challingo/core/helpers/json_validators.dart';
import 'package:challingo/features/login/domain/entities/check_phone_response_entity.dart';
import 'package:challingo/features/login/usecases/complete_profile_usecase.dart';
import 'package:challingo/features/login/usecases/confirm_otp_login_usecase.dart';
import 'package:challingo/features/login/usecases/confirm_register_usecase.dart';
import 'package:challingo/features/login/usecases/login_usecase.dart';
import 'package:challingo/features/login/usecases/otp_login_usecase.dart';
import 'package:challingo/features/login/usecases/register_usecase.dart';

import '../../../../core/interfaces/base_data_source.dart';
import '../../usecases/check_phone_usecase.dart';
import '../entities/login_response.dart';
import '../interfaces/login_data_source_interface.dart';

class LoginDataSourceRemote extends RemoteDataSource implements LoginDataSourceInterface {
  LoginDataSourceRemote(super.apiService);

  @override
  Future<UserEntity?> getUserByUsername(String username) {
    throw UnimplementedError();
  }

  @override
  Future<CheckPhoneResponseData?> checkPhone(CheckPhoneRequest request) async {
    final nr = await apiService.post(
      'Auth/check-phone',
      body: request.toJson(),
    );
    return parseBodyObjectOrNull(nr, CheckPhoneResponseData.fromJson);
  }

  @override
  Future<void> register(RegisterRequest request) async {
    await apiService.post(
      'Auth/register',
      body: request.toJson(),
    );
  }

  @override
  Future<String?> confirmRegister(ConfirmRegisterRequest request) async {
    final nr = await apiService.post(
      'Auth/register/confirm',
      body: request.toJson(),
    );
    return parseBodyObjectOrNull(
      nr,
      (json) => expectString(json, 'AccessToken'),
    );
  }

  @override
  Future<LoginResponseData?> login(LoginRequest request) async {
    final nr = await apiService.post(
      'Auth/login/password',
      body: request.toJson(),
    );
    return parseBodyObjectOrNull(nr, LoginResponseData.fromJson);
  }

  @override
  Future<void> completeProfile(CompleteProfileRequest request) async {
    final nr = await apiService.post(
      'Auth/register/complete-profile',
      body: request.toJson(),
    );
    if (!nr.success) return;
  }

  @override
  Future<void> otpLogin(OtpLoginRequest request) async {
    final nr = await apiService.post(
      'Auth/login/otp/request',
      body: request.toJson(),
    );
    if (!nr.success) return;
  }

  @override
  Future<LoginResponseData?> confirmOtpLogin(ConfirmOtpLoginRequest request) async {
    final nr = await apiService.post(
      'Auth/login/otp/confirm',
      body: request.toJson(),
    );
    return parseBodyObjectOrNull(nr, LoginResponseData.fromJson);
  }
}
