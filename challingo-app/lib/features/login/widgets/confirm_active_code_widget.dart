import 'dart:developer';

import '/widgets/buttons/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pinput/pinput.dart';

import '../../../core/extensions/context_extension.dart';
import '../../../core/theme/app_styles.dart';
import '../../../widgets/main_card.dart';
import '../login_view_state.dart';

class ConfirmActiveCodeWidget extends HookConsumerWidget {
  final Function onBack;
  final Function onChangePhone;
  final Function onResendCode;
  final PressController pressController = PressController();
  final Function(String code) onConfirmCode;
  final int timerValue;
   ConfirmActiveCodeWidget({super.key, required this.onBack, required this.onConfirmCode, required this.onChangePhone, required this.timerValue, required this.onResendCode});
  @override
  Widget build(BuildContext context ,WidgetRef ref) {
    final pinC = useTextEditingController();
    final isValidCode = useState(false);
    useEffect((){
      isValidCode.value = pinC.text.length ==6;
      return null;
    },[useListenable(pinC).text]);

    useEffect((){
      ref.read(receivedCodeProvider.notifier).addListener((a) {
        try {
          if(ref.read(signupStepProvider)==2) {
            pinC.setText(a);
          }
        }catch(e){
          log('error on auto $e');
        }
      });
      return null;
    },[]);


    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 56),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                  onPressed: () {
                    // ref.read(signupStepProvider.notifier).update((s) => 0);
                    onBack();
                  },
                  icon: const Icon(
                    Icons.arrow_back_outlined,
                    color: Color(0xff1F4A57),
                  )),
              Text(
                context.localizations.code,
                style: AppStyles.pageHeader,
              ),
            ],
          ),
        ),
        MainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.localizations.insertActivationCode,
                style: AppStyles.cardHeader,
              ),
              Text(
                context.localizations.weSentActivationCodeInsertIt,
                style: AppStyles.cardBody,
              ),
              const SizedBox(height: 12),
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xffEBEDEF),
                      width: 1,
                    )),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Pinput(
                    controller: pinC,
                    length: 6,
                    defaultPinTheme: const PinTheme(
                      width: 56,
                      height: 32,
                      textStyle: TextStyle(fontSize: 20, color: Color.fromRGBO(30, 60, 87, 1), fontWeight: FontWeight.w600),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xffCFD5DC))),
                      ),
                    ),
                    onCompleted: (pin) {
                      log('conde completed $pin');
                      Future.delayed(Duration(milliseconds: 300),(){
                        pressController.press();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.localizations.didNotReceiveCode,
                      style: AppStyles.cardWarning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    reverse: true,
                    label:context.localizations.changeNumber,
                    onPressed: () {
                      onChangePhone();
                      // return ref.read(signupStepProvider.notifier).update((s) => s - 1);
                    },
                  )
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "۰۰:${((timerValue)).toString().padLeft(2, '0')}",
                              style: AppStyles.cardWarning,
                            ),
                          ],
                        ),
                        Text(
                          context.localizations.to,
                          style: AppStyles.cardWarning,
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    reverse: true,
                    label:context.localizations.resend,
                    disabled: timerValue != 0,
                    icon: Icons.refresh,
                    onPressed: () async => await onResendCode(),
                  )
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.0),
          child: AppButton(
            controller: pressController,
            label: context.localizations.completeProfile,
            onPressed: () async {
              // await widget.myLoginController.confirmRegister(phoneC.text, pinC.text);
              await onConfirmCode(pinC.text);
            },
            disabled: !isValidCode.value,
            icon: Icons.person,
            // color: AppColors.actions,
          ),
        )
      ],
    );
  }
}
