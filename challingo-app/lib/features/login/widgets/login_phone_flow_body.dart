import '/features/login/widgets/complete_profile_widget.dart';
import '/features/login/widgets/confirm_active_code_widget.dart';
import '/features/login/widgets/initial_check_phone_widget.dart';
import '/features/login/widgets/login_with_otp_widget.dart';
import '/features/login/widgets/login_with_password_widget.dart';
import '/features/login/widgets/send_code_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/hooks/use_interval_hook.dart';
import '../login_controller.dart';
import '../login_view_state.dart';

/// Multi-step phone / OTP / register login flow (optional; off by default).
class LoginPhoneFlowBody extends HookConsumerWidget {
  const LoginPhoneFlowBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneC = useTextEditingController(text: '09');
    final loginController = ref.watch(loginControllerProvider);
    final step = ref.watch(signupStepProvider);
    final start = useState(60);
    final phone = useState(phoneC.text);

    useEffect(() {
      phone.value = phoneC.text;
      return null;
    }, [useListenable(phoneC).text]);

    useEffect(() {
      start.value = 60;
      return null;
    }, [step]);

    final resendCode = useCallback(() async {
      start.value = 60;
      await loginController.sendSMS(phoneC.text);
    }, []);

    final resendOtpLoginCode = useCallback(() async {
      start.value = 60;
      await loginController.otpLogin(phoneC.text);
    }, []);

    useInterval(() {
      if (start.value < 1) return;
      start.value = start.value - 1;
    }, const Duration(seconds: 1));

    return IndexedStack(
      index: step,
      children: [
        InitialCheckPhoneWidget(phoneC: phoneC),
        SendCodeWidget(onSendCode: resendCode, phone: phone.value),
        ConfirmActiveCodeWidget(
          onBack: () => ref.read(signupStepProvider.notifier).update((s) => 0),
          onConfirmCode: (code) => loginController.confirmRegister(phoneC.text, code),
          onChangePhone: () => ref.read(signupStepProvider.notifier).update((s) => s - 1),
          timerValue: start.value,
          onResendCode: resendCode,
        ),
        CompleteProfileWidget(phone: phone.value),
        LoginWithPasswordWidget(phoneC: phoneC),
        LoginWithOtpWidget(
          onBack: () => ref.read(signupStepProvider.notifier).update((s) => 4),
          onConfirmCode: (code) => loginController.confirmOtpLogin(phoneC.text, code),
          onChangePhone: () {},
          timerValue: start.value,
          onResendCode: resendOtpLoginCode,
        ),
      ],
    );
  }
}
