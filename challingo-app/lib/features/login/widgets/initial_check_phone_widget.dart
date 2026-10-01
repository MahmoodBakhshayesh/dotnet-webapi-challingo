
import '/features/login/login_controller.dart';
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

class InitialCheckPhoneWidget extends HookConsumerWidget {
  final TextEditingController phoneC;
  const InitialCheckPhoneWidget({super.key, required this.phoneC});

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    final loginController = ref.watch(loginControllerProvider);
    final refresher = useListenable(phoneC);
    final active = useState(false);
    useEffect((){
      active.value = phoneC.text.isValidPhone;
      return null;
    },[
      refresher
    ]);
    return  Column(
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
            label: context.localizations.loginOrSignup,
            onPressed: () async {
              await loginController.checkPhone(phoneC.text);
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
