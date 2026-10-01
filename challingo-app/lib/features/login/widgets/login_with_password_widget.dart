import '/features/login/login_controller.dart';
import '/widgets/buttons/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/extensions/context_extension.dart';
import '../../../core/extensions/string_extension.dart';
import '../../../core/helpers/input_formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_styles.dart';
import '../../../widgets/buttons/app_new_button.dart';
import 'package:challingo/widgets/inputs/challingo_field_decoration.dart';
import '../../../widgets/main_card.dart';

class LoginWithPasswordWidget extends HookConsumerWidget {
  final TextEditingController phoneC;
  const LoginWithPasswordWidget({super.key, required this.phoneC});
  @override
  Widget build(BuildContext context ,WidgetRef ref) {
    final loginController = ref.watch(loginControllerProvider);
    final passC = useTextEditingController();
    return  Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 56),

        Padding(
          padding: EdgeInsets.all(8.0),
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 12),
              Text(
                context.localizations.password,
                style: AppStyles.cardHeader,
              ),
              const SizedBox(height: 8),
              ChallingoFieldDecoration.textField(
                isPassword: true,
                controller: passC,
                keyboardType: TextInputType.visiblePassword,

              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  AppButton(label: context.localizations.otpLogin,onPressed: (){
                    loginController.otpLogin(phoneC.text);
                  },reverse: true,),
                ],
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
              await loginController.login(phoneC.text,passC.text);
            },
            disabled: !phoneC.text.isValidPhone,
            icon: Icons.phone_android_sharp,
            color: AppColors.actions,
          ),
        )
      ],
    );
  }
}
