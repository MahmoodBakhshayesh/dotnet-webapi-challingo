
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/extensions/context_extension.dart';
import '../../../core/extensions/string_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_styles.dart';
import '../../../widgets/buttons/app_new_button.dart';
import 'package:challingo/widgets/inputs/challingo_field_decoration.dart';
import '../../../widgets/main_card.dart';
import '../login_controller.dart';

class SendCodeWidget extends HookConsumerWidget {
  final String phone;
  final Function onSendCode;
  const SendCodeWidget({super.key, required this.onSendCode, required this.phone});
  @override
  Widget build(BuildContext context ,WidgetRef ref) {
    final loginController = ref.watch(loginControllerProvider);
    final phoneC = useTextEditingController.fromValue(TextEditingValue(text: phone));
    useEffect((){
      phoneC.text = phone;
      return null;
    },[phone]);
    final start= useState(60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 56),

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
              await loginController.sendSMS(phoneC.text);
              start.value = 60;
              // _start = 60;
              // setState(() {});
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
