import '/features/login/domain/entities/check_phone_response_entity.dart';
import '/features/login/usecases/confirm_otp_login_usecase.dart';
import '/features/login/usecases/confirm_register_usecase.dart';
import '/features/login/usecases/login_usecase.dart';
import '/features/login/usecases/otp_login_usecase.dart';
import '/features/login/usecases/register_usecase.dart';

import '../../usecases/check_phone_usecase.dart';
import '../../usecases/complete_profile_usecase.dart';
import '../entities/login_response.dart';

abstract class LoginDataSourceInterface {
  Future<UserEntity?> getUserByUsername(String username);
  Future<CheckPhoneResponseData?> checkPhone(CheckPhoneRequest phone);
  Future<void> register(RegisterRequest request);
  Future<LoginResponseData?> login(LoginRequest request);
  Future<LoginResponseData?> confirmOtpLogin(ConfirmOtpLoginRequest request);
  Future<String?> confirmRegister(ConfirmRegisterRequest request);
  Future<void> completeProfile(CompleteProfileRequest request);
  Future<void> otpLogin(OtpLoginRequest request);
}
