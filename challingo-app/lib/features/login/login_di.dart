import 'package:get_it/get_it.dart';
import 'package:challingo/core/helpers/di_feature_stack.dart';
import 'package:challingo/features/login/domain/data_sources/login_data_source_local.dart';
import 'package:challingo/features/login/domain/data_sources/login_data_source_remote.dart';
import 'package:challingo/features/login/domain/repositories/login_repository.dart';
import 'package:challingo/features/login/usecases/check_phone_usecase.dart';
import 'package:challingo/features/login/usecases/complete_profile_usecase.dart';
import 'package:challingo/features/login/usecases/confirm_otp_login_usecase.dart';
import 'package:challingo/features/login/usecases/confirm_register_usecase.dart';
import 'package:challingo/features/login/usecases/login_usecase.dart';
import 'package:challingo/features/login/usecases/otp_login_usecase.dart';
import 'package:challingo/features/login/usecases/register_usecase.dart';

void registerLoginDependencies(GetIt locator) {
  registerFeatureStack<LoginDataSourceLocal, LoginDataSourceRemote, LoginRepository>(
    locator: locator,
    name: 'LoginDataSource',
    createLocal: (l) => LoginDataSourceLocal(l()),
    createRemote: (l) => LoginDataSourceRemote(l()),
    createRepository: LoginRepository.builder,
  );

  locator.registerLazySingleton(() => LoginUsecase(locator()));
  locator.registerLazySingleton(() => CheckPhoneUsecase(locator()));
  locator.registerLazySingleton(() => RegisterUsecase(locator()));
  locator.registerLazySingleton(() => ConfirmRegisterUsecase(locator()));
  locator.registerLazySingleton(() => CompleteProfileUsecase(locator()));
  locator.registerLazySingleton(() => OtpLoginUsecase(locator()));
  locator.registerLazySingleton(() => ConfirmOtpLoginUsecase(locator()));
}
