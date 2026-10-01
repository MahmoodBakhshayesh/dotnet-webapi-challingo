import '/features/login/usecases/check_phone_usecase.dart';
import '/features/login/usecases/complete_profile_usecase.dart';
import '/features/login/usecases/confirm_otp_login_usecase.dart';
import '/features/login/usecases/otp_login_usecase.dart';
import '/features/login/usecases/register_usecase.dart';

import '../../usecases/confirm_register_usecase.dart';
import '../../usecases/login_usecase.dart';
import '../entities/login_response.dart';

abstract class LoginRepositoryInterface {
  Future<LoginResponse> login(LoginRequest request);
  Future<ConfirmOtpLoginResponse> confirmOtpLogin(ConfirmOtpLoginRequest request);
  Future<OtpLoginResponse> otpLogin(OtpLoginRequest request);
  Future<RegisterResponse> register(RegisterRequest request);
  Future<UserEntity?> getUserByUsername(String username);
  Future<CheckPhoneResponse> checkPhone(CheckPhoneRequest phone);
  Future<ConfirmRegisterResponse> confirmRegister(ConfirmRegisterRequest request);
  Future<CompleteProfileResponse> completeProfile(CompleteProfileRequest request);
  UserEntity? loadLoginResponse();
}
