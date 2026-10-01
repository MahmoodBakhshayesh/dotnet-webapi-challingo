import '/features/login/domain/entities/check_phone_response_entity.dart';
import '/features/login/usecases/complete_profile_usecase.dart';
import '/features/login/usecases/confirm_otp_login_usecase.dart';
import '/features/login/usecases/confirm_register_usecase.dart';
import '/features/login/usecases/login_usecase.dart';
import '/features/login/usecases/otp_login_usecase.dart';
import '/features/login/usecases/register_usecase.dart';
import 'package:sembast/sembast.dart';

import '../../../../core/database/sembast.dart';
import '../../../../core/interfaces/base_data_source.dart';
import '../../usecases/check_phone_usecase.dart';
import '../entities/login_response.dart';
import '../entities/offline_test_login.dart';
import '../interfaces/login_data_source_interface.dart';

class LoginDataSourceLocal extends LocalDataSource implements LoginDataSourceInterface {
  LoginDataSourceLocal(super.keyValueStore);

  @override
  Future<UserEntity?> getUserByUsername(String username) async {
    var finder = Finder(
        filter: Filter.equals('username', username),
        sortOrders: [SortOrder('name')]);

    var records = await SemBastDB.usersTable.find(SemBastDB.instance.db, finder: finder);
    if(records.isEmpty){
      return null;
    }else{
      return UserEntity.fromJson(records.first.value);
    }
  }

  @override
  Future<CheckPhoneResponseData?> checkPhone(CheckPhoneRequest phone)async {
    throw UnimplementedError();
  }

  @override
  Future<void> register(RegisterRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<String?> confirmRegister(ConfirmRegisterRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<LoginResponseData?> login(LoginRequest request) async {
    if (OfflineTestLogin.matches(request.phone, request.password)) {
      return OfflineTestLogin.buildResponse();
    }
    return null;
  }

  @override
  Future<void> completeProfile(CompleteProfileRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<void> otpLogin(OtpLoginRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<LoginResponseData?> confirmOtpLogin(ConfirmOtpLoginRequest request) {
    throw UnimplementedError();
  }
}
