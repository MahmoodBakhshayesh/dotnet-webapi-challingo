import 'dart:convert';
import 'dart:io';

import 'package:app_device_net_info/app_device_net_info.dart';
import 'package:challingo/core/helpers/api_service.dart';
import 'package:challingo/core/helpers/use_case_runner.dart';
import 'package:challingo/core/interfaces/base_result.dart';
import 'package:challingo/di.dart';
import 'package:challingo/features/login/usecases/check_phone_usecase.dart';
import 'package:challingo/features/login/usecases/complete_profile_usecase.dart';
import 'package:challingo/features/login/usecases/confirm_register_usecase.dart';
import 'package:challingo/features/login/usecases/otp_login_usecase.dart';
import 'package:challingo/features/login/usecases/register_usecase.dart';
import 'package:get_it/get_it.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:readsms/readsms.dart';
import '../../core/controllers/base_controller.dart';
import '../../core/data/app_data.dart';
import 'domain/entities/login_response.dart';
import 'login_view_state.dart';
import 'usecases/confirm_otp_login_usecase.dart';
import 'usecases/login_usecase.dart';

final loginControllerProvider = Provider.autoDispose((ref) {
  final loginUsecase = GetIt.instance.get<LoginUsecase>();
  final controller = LoginController(ref, loginUsecase);
  Future.microtask(controller.init);
  ref.onDispose(() => controller.dispose());
  return controller;
});

class LoginController extends BaseController {
  final LoginUsecase _loginUsecase;

  LoginController(super.ref, this._loginUsecase);

  @override
  void init() {
    setInitialHeaders();
    super.init();
  }

  Future<void> login(String username, String password) async {
    logger.i("Attempting login for user: '$username'");
    ref.read(loginErrorMessageProvider.notifier).state = null;
    ref.read(loginIsLoadingProvider.notifier).state = true;

    try {
      final loginData = await runUseCase(
        _loginUsecase,
        LoginRequest(phone: username, password: password),
      );
      loginWithResponse(loginData);
    } on Failure catch (f) {
      logger.w("Login failed for user: '$username'. Reason: ${f.message}");
      ref.read(loginErrorMessageProvider.notifier).state = f.message;
    } catch (e, st) {
      logger.e("An exception occurred during login for user: '$username'", error: e, stackTrace: st);
      ref.read(loginErrorMessageProvider.notifier).state = e.toString();
    } finally {
      ref.read(loginIsLoadingProvider.notifier).state = false;
    }
  }

  Future<void> checkPhone(String phone) async {
    try {
      final data = await runUseCase(
        locator<CheckPhoneUsecase>(),
        CheckPhoneRequest(phone: phone),
      );
      logger.i("Login successful for user: '${data.exists}'");
      logger.i(jsonEncode(data.toJson()));
      if (data.exists) {
        if (data.requiresRegistration) {
          ref.read(signupStepProvider.notifier).update((s) => 2);
          sendSMS(phone);
        } else {
          if (!data.isProfileCompleted) {
            ref.read(signupStepProvider.notifier).update((s) => 2);
            sendSMS(phone);
          } else {
            ref.read(signupStepProvider.notifier).update((s) => 4);
          }
        }
      } else {
        ref.read(signupStepProvider.notifier).update((s) => 2);
        sendSMS(phone);
      }
    } on Failure catch (f) {
      logger.e('error -> ${f.message}');
    }
  }

  Future<void> checkUser() async {
    final sp = await sharedPreferencesAsync;
    String? userJson = sp.getString('User');
    if (userJson == null) {
      return;
    }

    LoginResponseData loginData = LoginResponseData.fromJson(jsonDecode(userJson));
    loginWithResponse(loginData);
  }

  Future<void> confirmRegister(String phone, String code) async {
    try {
      final token = await runUseCase(
        locator<ConfirmRegisterUsecase>(),
        ConfirmRegisterRequest(phone: phone, code: code),
      );
      logger.i("User Confrimed'");
      AppData.instance.setToken(token);
      ref.read(signupStepProvider.notifier).update((s) => 3);
    } on Failure {
      // FailureBus already notified by use case
    }
  }

  listenForCode() async {
    if (Platform.isAndroid || Platform.isIOS) {
      getSmsReadPermission().then((v) {
        if (v) {
          final plugin = Readsms();
          plugin.read();
          plugin.smsStream.listen((event) {
            String? extractedCode = extractCodeFromMessage(event.body);
            if (extractedCode == null) {
              return;
            } else {
              ref.read(receivedCodeProvider.notifier).update((s) => extractedCode);
              plugin.dispose();
            }
          });
        }
      });
    }
  }

  Future<bool> getSmsReadPermission() async {
    if (await Permission.sms.status == PermissionStatus.granted) {
      return true;
    } else {
      if (await Permission.sms.request() == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    }
  }

  String? extractCodeFromMessage(String message) {
    final RegExp codeRegExp = RegExp(r'\b\d{6}\b');
    final match = codeRegExp.firstMatch(message);
    if (match != null) {
      return match.group(0);
    }
    return null;
  }

  Future<void> sendSMS(String phone) async {
    final ok = await runVoidUseCase(
      locator<RegisterUsecase>(),
      RegisterRequest(phone: phone),
    );
    if (ok) {
      logger.i("User Register Done'");
      ref.read(signupStepProvider.notifier).update((s) => 2);
      listenForCode();
    }
  }

  Future<void> loginWithResponse(LoginResponseData loginData) async {
    ref.read(authenticatedUserProvider.notifier).state = loginData.user;

    AppData.instance.setUserId(loginData.user.id);
    AppData.instance.setToken(loginData.accessToken);
    final sp = await sharedPreferencesAsync;
    await sp.setString('User', jsonEncode(loginData.toJson()));
    ref.read(signupStepProvider.notifier).update((s) => 0);
  }

  Future<void> completeProfile({required String phone, required String password, required String name}) async {
    try {
      logger.e('completeProfile');
      final ok = await runVoidUseCase(
        locator<CompleteProfileUsecase>(),
        CompleteProfileRequest(password: password, fullName: name),
      );
      if (ok) {
        await login(phone, password);
      }
    } catch (e) {
      if (e is Error) {
        logger.e(e.stackTrace.toString());
      }
    }
  }

  requestOtpLogin(String phone) async {
    final ok = await runVoidUseCase(
      locator<OtpLoginUsecase>(),
      OtpLoginRequest(phone: phone),
    );
    if (ok) {
      listenForCode();
    }
  }

  Future<void> otpLogin(String phone) async {
    ref.read(signupStepProvider.notifier).update((s) => 5);
    await requestOtpLogin(phone);
  }

  Future<void> confirmOtpLogin(String phone, String code) async {
    try {
      final loginData = await runUseCase(
        locator<ConfirmOtpLoginUsecase>(),
        ConfirmOtpLoginRequest(phone: phone, code: code),
      );
      loginWithResponse(loginData);
    } on Failure catch (f) {
      ref.read(loginErrorMessageProvider.notifier).state = f.message;
    }
  }

  Future<void> setInitialHeaders() async {
    final AppInfoData infoData = await AppDeviceNetworkInfo.getAppInfo();
    final apiService = locator<ApiService>();
    apiService.addHeader({
      'X-App-Version': infoData.versionKey,
    });
  }
}
