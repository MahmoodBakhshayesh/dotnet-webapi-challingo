import 'dart:async';

import '/core/extensions/context_extension.dart';
import '/core/theme/app_colors.dart';
import 'package:challingo/widgets/inputs/challingo_field_decoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pinput/pinput.dart';

import '../../../core/extensions/string_extension.dart';
import '../../../core/helpers/input_formatters.dart';
import '../../../core/theme/app_styles.dart';
import '../../../widgets/buttons/app_button.dart';
import '../../../widgets/buttons/app_new_button.dart';
import '../../../widgets/main_card.dart';
import '../login_controller.dart';
import '../login_view_state.dart';

class SignupViewPhone extends ConsumerStatefulWidget {
  final LoginController myLoginController;
  const SignupViewPhone({super.key, required this.myLoginController});

  @override
  ConsumerState<SignupViewPhone> createState() => _SignupViewPhoneState();
}

class _SignupViewPhoneState extends ConsumerState<SignupViewPhone> {
  final TextEditingController phoneC = TextEditingController();
  final TextEditingController passwordC = TextEditingController();
  final TextEditingController pinC = TextEditingController();
  final TextEditingController nameC = TextEditingController();

  Timer? _timer;
  int _start = 60;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    phoneC.addListener(() {
      if(mounted) {
        setState(() {});
      }
    });
    pinC.addListener(() {
      if(mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.myLoginController.checkUser();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => tic());
    ref.read(receivedCodeProvider.notifier).addListener((a) {
      pinC.setText(a);
      if (a.isNotEmpty) {
        widget.myLoginController.confirmRegister(phoneC.text, a);
      }
    });

    super.initState();
  }

  tic() {
    if (_start < 1 || _start == 0) return;
    _start = _start - 1;
    setState(() {});
  }

  resendCode() async {
    _start = 60;
    setState(() {});
    await widget.myLoginController.sendSMS(phoneC.text);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
          backgroundColor: AppColors.scaffoldBackgroundColor,
          body: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              bool checkinUser = ref.watch(checkingUserProvider);
              if (checkinUser) {
                return  Center(child: SpinKitCubeGrid(color: AppColors.primaryColor, size: 100));
              }
              int step = ref.watch(signupStepProvider);
              return IndexedStack(
                index: step,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 56),
                      Row(
                        children: [
                          // Padding(
                          //     padding: const EdgeInsets.all(16.0),
                          //     child: Image.asset(
                          //       AssetImages.icon,
                          //       width: 64,
                          //       height: 64,
                          //     )),
                        ],
                      ),
                       Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                             context.localizations.welcomeTitle ,
                              style: AppStyles.pageHeader,
                            ),
                            Text(
                              context.localizations.plzInsertPhoneNumber ,
                              style: AppStyles.pageBody,
                            ),
                          ],
                        ),
                      ),
                      MainCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                              context.localizations.phone ,
                              style: AppStyles.cardHeader,
                            ),
                            const SizedBox(height: 12),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: ChallingoFieldDecoration.textField(
                                placeholder: context.localizations.phoneEg,
                                controller: phoneC,
                                keyboardType: TextInputType.phone,
                                maxLength: 11,
                                inputFormatters: [
                                  MyInputFormatter.justNumber,

                                  PersianToEnglishNumberFormatter(),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.0),
                        child: AppNewButton(
                          label: context.localizations.checkPhone,
                          onPressed: () async {
                            await widget.myLoginController.checkPhone(phoneC.text);
                          },
                          disabled: !phoneC.text.isValidPhone,
                          icon: Icons.phone_android_sharp,
                          color: AppColors.actions,
                        ),
                      )
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 56),
                      Row(
                        children: [
                          // Padding(
                          //     padding: const EdgeInsets.all(16.0),
                          //     child: Image.asset(
                          //       AssetImages.icon,
                          //       width: 64,
                          //       height: 64,
                          //     )),
                        ],
                      ),
                       Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.localizations.welcomeTitle,
                              style: AppStyles.pageHeader,
                            ),
                            Text(
                             context.localizations.plzInsertPhoneNumber,
                              style: AppStyles.pageBody,
                            ),
                          ],
                        ),
                      ),
                      MainCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                              context.localizations.phone,
                              style: AppStyles.cardHeader,
                            ),
                            const SizedBox(height: 12),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: ChallingoFieldDecoration.textField(
                                controller: phoneC,
                                locked: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.0),
                        child: AppNewButton(
                          label: context.localizations.sendActivationCode,
                          onPressed: () async {
                            await widget.myLoginController.sendSMS(phoneC.text);
                            _start = 60;
                            setState(() {});
                          },
                          disabled: !phoneC.text.isValidPhone,
                          icon: Icons.phone_android_sharp,
                          color: AppColors.actions,
                        ),
                      )
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            IconButton(
                                onPressed: () {
                                  ref.read(signupStepProvider.notifier).update((s) => 0);
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
                                  onCompleted: (_) {},
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
                                  label:context.localizations.changeNumber,
                                  onPressed: () => ref.read(signupStepProvider.notifier).update((s) => s - 1),
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
                                            "۰۰:${((_start)).toString().padLeft(2, '0')}",
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
                                  label:context.localizations.resend,
                                  disabled: _start != 0,
                                  icon: Icons.refresh,
                                  onPressed: () async => await resendCode(),
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
                          label: context.localizations.completeProfile,
                          onPressed: () async {
                            await widget.myLoginController.confirmRegister(phoneC.text, pinC.text);
                          },
                          disabled: pinC.text.length != 6,
                          icon: Icons.person,
                          // color: AppColors.actions,
                        ),
                      )
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                       Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                         context.localizations.completeProfile ,
                          style: AppStyles.pageHeader,
                        ),
                      ),
                       Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                        child: Text(
                          context.localizations.welcome,
                          style: AppStyles.cardHeader,
                        ),
                      ),
                      MainCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                              context.localizations.insertYourName,
                              style: AppStyles.cardHeader,
                            ),
                            const SizedBox(height: 12),
                            ChallingoFieldDecoration.textField(
                              placeholder: context.localizations.name,
                              controller: nameC,
                            )
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.0),
                        child: AppNewButton(
                          label: context.localizations.submit,
                          onPressed: () async {
                            // await mySignupControllerySignupController.completeInfo(nameC.text);
                          },
                          disabled: phoneC.text.isEmpty,
                          icon: Icons.arrow_forward,
                          color: AppColors.actions,
                        ),
                      )
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 56),
                      Row(
                        children: [
                          // Padding(
                          //     padding: const EdgeInsets.all(16.0),
                          //     child: Image.asset(
                          //       AssetImages.icon,
                          //       width: 64,
                          //       height: 64,
                          //     )),
                        ],
                      ),
                       Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.localizations.welcomeTitle,
                              style: AppStyles.pageHeader,
                            ),
                            Text(
                              context.localizations.enterPasswordToEnter,
                              style: AppStyles.pageBody,
                            ),
                          ],
                        ),
                      ),
                      MainCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                              context.localizations.phone,
                              style: AppStyles.cardHeader,
                            ),
                            const SizedBox(height: 12),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: ChallingoFieldDecoration.textField(
                                placeholder: context.localizations.phoneEg,
                                controller: phoneC,
                                keyboardType: TextInputType.phone,
                                locked: true,
                                maxLength: 11,
                                inputFormatters: [
                                  MyInputFormatter.justNumber,

                                  PersianToEnglishNumberFormatter(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                             Text(
                              context.localizations.password,
                              style: AppStyles.cardHeader,
                            ),
                            const SizedBox(height: 12),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: ChallingoFieldDecoration.textField(
                                isPassword: true,
                                controller: passwordC,
                                keyboardType: TextInputType.visiblePassword,

                              ),
                            )
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.0),
                        child: AppNewButton(
                          label: context.localizations.login,
                          onPressed: () async {
                            await widget.myLoginController.login(phoneC.text,passwordC.text);
                          },
                          disabled: !phoneC.text.isValidPhone,
                          icon: Icons.phone_android_sharp,
                          color: AppColors.actions,
                        ),
                      )
                    ],
                  ),
                  Text('Login with OTP'),

                ],
              );
            },
          )),
    );
  }
}



